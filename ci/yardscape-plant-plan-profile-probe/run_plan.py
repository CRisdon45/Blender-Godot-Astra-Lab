from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
PROFILE=ROOT.parent/'yardscape-plant-form-profile-probe'
PIN='4.7.1.stable.official.a13da4feb';ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
PROFILE_FILES=[
 'presentation/northstar/foliage/plant_form_profiles.gd',
 'presentation/northstar/foliage/plant_form_layout.gd'
]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('profile_verify',PROFILE/'run_profile.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.verify()
    expected={'northstar-profile-plan-symbols.tscn','presentation/northstar/plan_profile_study.gd','presentation/northstar/plan/profiled_plan_symbol.gd'}
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=expected:raise ValueError('Unexpected Plan-profile source expansion')
    for name in actual:
        p=ROOT/'project'/name
        if p.is_symlink() or '..' in Path(name).parts:raise ValueError('Invalid path')
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Forbidden dependency '+name)
        if re.search(r'\b(Node3D|MeshInstance3D|ArrayMesh|Mesh\.|surface_get_arrays|profiled_batched_dab_tree)\b',text):raise ValueError('3D readback/render dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith(('.gd','.tscn')) and not ((ROOT/'project'/ref).is_file() or ref in PROFILE_FILES):raise ValueError('Unresolved '+ref)
    return True
def run():
    verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Remote worker only')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'plant-plan-profile'
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(ROOT/'project',stage)
    for rel in PROFILE_FILES:
        source=PROFILE/'project'/rel;dest=stage/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
    shutil.copyfile(ROOT/'plan_probe.gd',stage/'plan_probe.gd')
    (stage/'project.godot').write_text('''config_version=5
[application]
config/name="Direct plant profile Plan symbols"
run/main_scene="res://northstar-profile-plan-symbols.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    inside=stage/'.local/output';inside.mkdir(parents=True);out=Path(os.environ['RUNNER_TEMP'])/'plant-plan-profile-evidence';out.mkdir(exist_ok=False)
    rid=str(uuid.uuid4());env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))};env.update(YARDSCAPE_PLAN_PROFILE_OUTPUT=str(inside),YARDSCAPE_PLAN_PROFILE_RUN_ID=rid,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1');status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://plan_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://plan_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=rid or not report.get('passed') or report.get('failures'):raise RuntimeError('Failed report')
        if len(list(inside.glob('*.png')))!=5:raise ValueError('Expected five images')
        status='plant_plan_profile_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z-]+\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest={"status":status,"run_id":rid,"public_commit":os.environ.get('GITHUB_SHA'),"engine":version,"engine_sha256":ENGINE_SHA,"runner_sha256":sha(Path(__file__)),"plan_source_sha256":{p.relative_to(ROOT/'project').as_posix():sha(p) for p in sorted((ROOT/'project').rglob('*')) if p.is_file()},"shared_profile_inputs_sha256":{rel:sha(PROFILE/'project'/rel) for rel in PROFILE_FILES},"output_sha256":{p.name:sha(p) for p in sorted(out.glob('*.png'))}}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Direct Plan profile boundary verified')
    else:run()
