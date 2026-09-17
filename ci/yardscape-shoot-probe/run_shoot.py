"""Bounded public shoot experiment. Native Godot runs only on GitHub Linux."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
SPATIAL=ROOT.parent/'yardscape-spatial-probe'
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('spatial_verify',SPATIAL/'run_spatial.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    spatial=module.verify()
    expected={'northstar-spatial-shoot.tscn','presentation/northstar/spatial_shoot_study.gd','presentation/northstar/shoot/compact_shoot.gd','presentation/northstar/shoot/shoot_foliage.gdshader','tests/shoot_probe.gd'}
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=expected: raise ValueError('Unexpected shoot source expansion')
    for name in actual:
        p=ROOT/'project'/name
        if p.is_symlink() or '..' in Path(name).parts: raise ValueError('Invalid source path')
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text): raise ValueError('Forbidden dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith(('.gd','.gdshader','.gdshaderinc','.tscn')) and not (ROOT/'project'/ref).is_file() and not (SPATIAL/'project'/ref).is_file(): raise ValueError('Unresolved resource '+ref)
        if name.endswith('.gdshader'):
            code=re.sub(r'//[^\n]*','',text)
            if re.search(r'\b(TIME|SCREEN_UV|ALPHA|EMISSION|hint_screen_texture|hint_depth_texture)\b|\bVERTEX\s*=',code): raise ValueError('Unreviewed foliage shading mode')
    return spatial

def run():
    spatial=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux': raise RuntimeError('Native execution restricted to authorized Linux worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA: raise ValueError('Pinned engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN: raise ValueError('Pinned engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'compact-shoot-probe'
    if stage.exists(): raise FileExistsError('Fresh stage required')
    shutil.copytree(SPATIAL/'project',stage)
    for p in (ROOT/'project').rglob('*'):
        if p.is_file():
            dest=stage/p.relative_to(ROOT/'project');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
    project='''config_version=5
[application]
config/name="Compact 3D foliage shoot probe"
run/main_scene="res://northstar-spatial-shoot.tscn"
[display]
window/size/viewport_width=800
window/size/viewport_height=600
[rendering]
renderer/rendering_method="gl_compatibility"
'''
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/'shoot-evidence';out.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_SHOOT_OUTPUT=str(inside),YARDSCAPE_SHOOT_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/shoot_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/shoot_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=75,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text): raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'): raise RuntimeError('Missing, stale or failed report')
        if not report.get('adapter') or report['adapter']=='Dummy': raise RuntimeError('No real framebuffer')
        if len(list(inside.glob('*.png')))!=7: raise ValueError('Expected seven native shoot captures')
        status='compact_shoot_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z-]+\.png',p.name): shutil.copyfile(p,out/p.name)
        manifest={"status":status,"run_id":run_id,"engine":version,"engine_sha256":ENGINE_SHA,"public_commit":os.environ.get('GITHUB_SHA'),"spatial_sources":spatial['sources'],"runner_sha256":sha(Path(__file__)),"source_sha256":{p.relative_to(ROOT/'project').as_posix():sha(p) for p in sorted((ROOT/'project').rglob('*')) if p.is_file()},"output_sha256":{p.name:sha(p) for p in sorted(out.glob('*.png'))}}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Compact shoot native look complete; no whole-tree or tablet acceptance.')
if __name__=='__main__':
    if '--verify-only' in sys.argv: verify();print('Compact shoot source and retained spatial dependency boundary verified')
    else: run()
