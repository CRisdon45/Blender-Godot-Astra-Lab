"""Only the authorized public Linux worker executes Godot; no private source fetch."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent/'yardscape-spatial-probe'
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('spatial_verify',BASE/'run_spatial.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    base=module.verify()
    manifest=json.loads((ROOT/'source_manifest.json').read_text())
    expected=set(manifest['sources'])
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=expected:raise ValueError('Candidate source allowlist differs')
    for name,record in manifest['sources'].items():
        p=ROOT/'project'/name
        if p.is_symlink() or sha(p)!=record['sha256']:raise ValueError('Source mismatch '+name)
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Unreviewed dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if not (ROOT/'project'/ref).is_file() and not (BASE/'project'/ref).is_file():raise ValueError('Unresolved resource '+ref)
        if name.endswith('.gdshader'):
            code=re.sub(r'//[^\n]*','',text)
            if re.search(r'\b(TIME|SCREEN_UV|ALPHA|EMISSION|hint_screen_texture|hint_depth_texture)\b|\bVERTEX\s*=',code):raise ValueError('Unreviewed foliage shading mode')
    return manifest,base

def run():
    manifest,base=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Native execution restricted to authorized worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine checksum mismatch')
    version=subprocess.run([str(engine),'--version'],text=True,capture_output=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'canopy-probe'
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(BASE/'project',stage)
    for name in manifest['sources']:
        p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'project'/name,p)
    shutil.copyfile(ROOT/'canopy_probe.gd',stage/'tests/canopy_probe.gd')
    project='config_version=5\n[application]\nconfig/name="Public spatial canopy test"\nrun/main_scene="res://northstar-spatial-canopy.tscn"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/'canopy-evidence';out.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_CANOPY_RUN_ID=run_id,YARDSCAPE_CANOPY_OUTPUT=str(inside),LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status='failed'
    try:
        commands=[('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/canopy_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/canopy_probe.gd'])]
        for name,command in commands:
            with (out/name).open('w') as log:result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,check=False)
            text=(out/name).read_text(errors='replace');print(text[-18000:])
            if result.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native check failed '+name)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):raise RuntimeError('Stale/missing/failed report')
        if not report.get('adapter') or report['adapter']=='Dummy':raise RuntimeError('No real framebuffer')
        if len(list(inside.glob('*.png')))!=27:raise ValueError('Expected 19 images plus eight motion samples')
        status='canopy_checks_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'(?:\d\d-[a-z-]+|motion-\d\d)\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest.update(status=status,run_id=run_id,public_commit=os.environ.get('GITHUB_SHA'),engine=version,engine_sha256=ENGINE_SHA,base_sources=base['sources'],runner_sha256=sha(Path(__file__)),probe_sha256=sha(ROOT/'canopy_probe.gd'),output_sha256={p.name:sha(p) for p in sorted(out.glob('*.png'))})
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Canopy scope and retained spatial sources verified')
    else:run()
