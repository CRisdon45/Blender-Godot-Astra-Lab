"Run the reviewed compact-group witness only on the authorized public Linux worker."
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
SPATIAL=ROOT.parent/'yardscape-spatial-probe'
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('spatial_verify',SPATIAL/'run_spatial.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    spatial=module.verify()
    manifest=json.loads((ROOT/'source_manifest.json').read_text())
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=set(manifest['sources']):raise ValueError('Unexpected candidate source expansion')
    for name,record in manifest['sources'].items():
        p=ROOT/'project'/name
        if p.is_symlink() or '..' in Path(name).parts or sha(p)!=record['sha256']:raise ValueError('Source mismatch '+name)
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Unreviewed dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if not (ROOT/'project'/ref).is_file() and not (SPATIAL/'project'/ref).is_file():raise ValueError('Unresolved '+ref)
        if name.endswith('.gdshader'):
            code=re.sub(r'//[^\n]*','',text)
            if re.search(r'\b(TIME|SCREEN_UV|ALPHA|EMISSION|hint_screen_texture|hint_depth_texture)\b|\bVERTEX\s*=',code):raise ValueError('Unreviewed shader dependency')
    return manifest,spatial
def run():
    manifest,spatial=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Native execution restricted to authorized Linux worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Pinned engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Pinned engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'compact-foliage-group'
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(SPATIAL/'project',stage)
    for p in (ROOT/'project').rglob('*'):
        if p.is_file():
            dest=stage/p.relative_to(ROOT/'project');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
    shutil.copyfile(ROOT/'group_probe.gd',stage/'tests/group_probe.gd')
    project='config_version=5\n[application]\nconfig/name="Compact foliage group witness"\nrun/main_scene="res://northstar-foliage-group.tscn"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/'foliage-group-evidence';out.mkdir(exist_ok=False)
    rid=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_GROUP_OUTPUT=str(inside),YARDSCAPE_GROUP_RUN_ID=rid,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/group_probe.gd','--check-only']),
                            ('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/group_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native check failed '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=rid or not report.get('passed') or report.get('failures'):raise RuntimeError('Failed or stale report')
        if not report.get('adapter') or report['adapter']=='Dummy':raise RuntimeError('No real framebuffer')
        if len(list(inside.glob('*.png')))!=10:raise ValueError('Expected ten visual witnesses')
        status='compact_group_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z-]+\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest.update(status=status,run_id=rid,public_commit=os.environ.get('GITHUB_SHA'),engine=version,engine_sha256=ENGINE_SHA,
                        retained_spatial_sources=spatial['sources'],runner_sha256=sha(Path(__file__)),probe_sha256=sha(ROOT/'group_probe.gd'),
                        output_sha256={p.name:sha(p) for p in sorted(out.glob('*.png'))})
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Compact-group source boundary verified')
    else:run()
