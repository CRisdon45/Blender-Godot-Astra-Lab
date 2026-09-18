"""Small-look whole-tree experiment on the approved public Linux worker."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
SPATIAL=ROOT.parent/'yardscape-spatial-probe'
CANOPY=ROOT.parent/'yardscape-canopy-probe'
SHOOT=ROOT.parent/'yardscape-shoot-probe'
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    for runner,name in [(SPATIAL/'run_spatial.py','spatial'),(SHOOT/'run_shoot.py','shoot')]:
        spec=importlib.util.spec_from_file_location(name,runner);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.verify()
    expected={'northstar-spatial-interleaved-tree.tscn','presentation/northstar/spatial_interleaved_tree_study.gd','presentation/northstar/shoot/interleaved_tree.gd','tests/tree_probe.gd'}
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=expected:raise ValueError('Unexpected tree-probe source expansion')
    for name in actual:
        p=ROOT/'project'/name;text=p.read_text()
        if p.is_symlink() or '..' in Path(name).parts:raise ValueError('Invalid path')
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Forbidden dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            candidates=[ROOT/'project'/ref,SPATIAL/'project'/ref,SHOOT/'project'/ref,CANOPY/'project'/ref]
            if ref.endswith(('.gd','.gdshader','.gdshaderinc','.tscn')) and not any(x.is_file() for x in candidates):raise ValueError('Unresolved '+ref)
    return True

def run():
    verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Native execution only on authorized worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'interleaved-shoot-tree'
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(SPATIAL/'project',stage)
    for rel in ['presentation/northstar/canopy/illustrative_tree.gd','presentation/northstar/canopy/foliage.gdshader']:
        src=CANOPY/'project'/rel;dst=stage/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for rel in ['presentation/northstar/shoot/compact_shoot.gd','presentation/northstar/shoot/shoot_foliage.gdshader']:
        src=SHOOT/'project'/rel;dst=stage/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for p in (ROOT/'project').rglob('*'):
        if p.is_file():
            dst=stage/p.relative_to(ROOT/'project');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst)
    project='''config_version=5
[application]
config/name="Interleaved compact-shoot tree probe"
run/main_scene="res://northstar-spatial-interleaved-tree.tscn"
[display]
window/size/viewport_width=960
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
'''
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/'shoot-tree-evidence';out.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_TREE_OUTPUT=str(inside),YARDSCAPE_TREE_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status='failed'
    try:
        for logname,cmd,limit in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/tree_probe.gd','--check-only'],25),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/tree_probe.gd'],120)]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=limit,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-18000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):raise RuntimeError('Missing/stale/failed report')
        if not report.get('adapter') or report['adapter']=='Dummy':raise RuntimeError('No real framebuffer')
        if len(list(inside.glob('*.png')))!=8:raise ValueError('Expected eight tree captures')
        status='interleaved_tree_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z-]+\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest={"status":status,"run_id":run_id,"engine":version,"engine_sha256":ENGINE_SHA,"public_commit":os.environ.get('GITHUB_SHA'),"runner_sha256":sha(Path(__file__)),"source_sha256":{p.relative_to(ROOT/'project').as_posix():sha(p) for p in sorted((ROOT/'project').rglob('*')) if p.is_file()},"output_sha256":{p.name:sha(p) for p in sorted(out.glob('*.png'))}}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Interleaved tree source/dependency boundary verified')
    else:run()
