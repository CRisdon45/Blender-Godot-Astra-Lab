from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent;SPATIAL=ROOT.parent/'yardscape-spatial-probe';GROUP=ROOT.parent/'yardscape-foliage-group-probe';PIN='4.7.1.stable.official.a13da4feb';ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('spatial_verify',SPATIAL/'run_spatial.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);spatial=m.verify()
    manifest=json.loads((ROOT/'source_manifest.json').read_text());actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=set(manifest['sources']):raise ValueError('Unexpected candidate source expansion')
    for name in manifest['sources']:
        p=ROOT/'project'/name
        if p.is_symlink() or '..' in Path(name).parts:raise ValueError('Invalid path')
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Forbidden dependency')
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if not any((b/'project'/ref).is_file() for b in (ROOT,SPATIAL,GROUP)):raise ValueError('Unresolved '+ref)
    return manifest,spatial
def run():
    manifest,spatial=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Remote worker only')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'mixed-group';shutil.copytree(SPATIAL/'project',stage)
    for b in (GROUP,ROOT):
        for p in (b/'project').rglob('*'):
            if p.is_file():
                d=stage/p.relative_to(b/'project');d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,d)
    shutil.copyfile(ROOT/'mixed_probe.gd',stage/'tests/mixed_probe.gd');(stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Mixed foliage group comparison"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    inside=stage/'.local/output';inside.mkdir(parents=True);out=Path(os.environ['RUNNER_TEMP'])/'mixed-group-evidence';out.mkdir(exist_ok=False);rid=str(uuid.uuid4());env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))};env.update(YARDSCAPE_MIXED_OUTPUT=str(inside),YARDSCAPE_MIXED_RUN_ID=rid,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1');status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/mixed_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/mixed_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=rid or not report.get('passed') or report.get('failures'):raise RuntimeError('Failed report')
        if len(list(inside.glob('*.png')))!=12:raise ValueError('Expected twelve images')
        status='mixed_group_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z-]+\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest.update(status=status,run_id=rid,public_commit=os.environ.get('GITHUB_SHA'),engine=version,engine_sha256=ENGINE_SHA,executed_source_sha256={name:sha(ROOT/'project'/name) for name in manifest['sources']},retained_spatial_sources=spatial['sources'],output_sha256={p.name:sha(p) for p in sorted(out.glob('*.png'))})
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Mixed-group source boundary verified')
    else:run()
