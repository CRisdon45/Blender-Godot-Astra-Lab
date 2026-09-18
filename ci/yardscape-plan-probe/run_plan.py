"""Public, display-only plan probe. Native execution only on Linux GitHub CI."""
from pathlib import Path, PurePosixPath
import base64, hashlib, json, lzma, os, re, shutil, subprocess, sys, uuid
ROOT = Path(__file__).resolve().parent
LEAF = ROOT.parent / 'yardscape-renderer'
PIN = '4.7.1.stable.official.a13da4feb'
ENGINE_SHA = '32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def unique_pairs(pairs):
    result = {}
    for k,v in pairs:
        if k in result: raise ValueError('Duplicate manifest/source key')
        result[k] = v
    return result

def sources():
    index = json.loads((ROOT/'source_index.json').read_text(),object_pairs_hook=unique_pairs)
    parts = []
    for name,wanted in index['encoded_parts'].items():
        p = ROOT/name
        if p.is_symlink() or sha(p.read_bytes()) != wanted: raise ValueError('Source pack part mismatch')
        parts.append(p.read_text().strip())
    packed = base64.b64decode(''.join(parts),validate=True)
    if sha(packed) != index['packed_sha256']: raise ValueError('Packed source mismatch')
    raw = lzma.decompress(packed,memlimit=256*1024*1024)
    if len(raw)>2*1024*1024: raise ValueError('Oversized source payload')
    files = json.loads(raw,object_pairs_hook=unique_pairs)
    if set(files) != set(index['files']): raise ValueError('Source allowlist mismatch')
    result = {}
    for name,text in files.items():
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or not name.startswith('presentation/northstar/'):
            raise ValueError('Forbidden source path')
        data=text.encode('utf-8')
        if sha(data) != index['files'][name]['sha256']: raise ValueError('Source byte identity mismatch: '+name)
        result[name] = data
    leaf_index = json.loads((LEAF/'source_manifest.json').read_text())
    if len(leaf_index['source_sha256']) != 8: raise ValueError('Unexpected leaf dependency expansion')
    for name,wanted in leaf_index['source_sha256'].items():
        if name in result: raise ValueError('Plan package must not override verified leaf components')
        data = (LEAF/'project'/name).read_bytes()
        if sha(data)!=wanted: raise ValueError('Verified leaf component changed: '+name)
        result[name] = data
    for name,data in result.items():
        text = data.decode('utf-8')
        if re.search(r'(https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/)',text):
            raise ValueError('Forbidden private/network dependency: '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith(('.gd','.gdshader','.gdshaderinc')) and ref not in result:
                raise ValueError('Unresolved renderer dependency: '+ref)
    return result,index

def execute():
    files,index = sources()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':
        raise RuntimeError('Native Godot runs only on the authorized Linux GitHub worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine.read_bytes())!=ENGINE_SHA: raise ValueError('Pinned engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,timeout=20,check=True).stdout.strip()
    if version!=PIN: raise ValueError('Pinned version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'public-plan-probe'
    stage.mkdir(exist_ok=False)
    for name,data in files.items():
        p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    (stage/'tests').mkdir()
    shutil.copyfile(ROOT/'plan_probe.gd',stage/'tests/plan_probe.gd')
    project='''config_version=5
[application]
config/name="Public display-only plan probe"
run/main_scene="res://northstar-regions.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
[rendering]
renderer/rendering_method="gl_compatibility"
'''
    scene='''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://presentation/northstar/regions/broadleaf_shade_study.gd" id="1"]
[node name="DisplayPlan" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
'''
    (stage/'project.godot').write_text(project)
    (stage/'northstar-regions.tscn').write_text(scene)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    output=Path(os.environ['RUNNER_TEMP'])/'public-plan-artifacts';output.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_PUBLIC_RUN_ID=run_id,YARDSCAPE_REGION_OUTPUT=str(inside),LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    commands=[('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/plan_probe.gd','--check-only']),
              ('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/plan_probe.gd'])]
    status='failed'
    try:
        for name,cmd in commands:
            with (output/name).open('w') as log:
                completed=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=480,check=False)
            text=(output/name).read_text(errors='replace');print(text[-12000:])
            if completed.returncode or re.search(r'(SCRIPT ERROR:|SHADER ERROR:|ERROR:)',text):
                raise RuntimeError('Native check failed: '+name)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):
            raise RuntimeError('Missing, stale or failed report')
        if not report.get('adapter') or report['adapter']=='Dummy': raise RuntimeError('No native framebuffer adapter')
        if len(list(inside.glob('*.png')))!=24: raise RuntimeError('Expected 23 captures and one export')
        status='display_plan_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or (p.suffix=='.png' and re.fullmatch(r'(?:\d\d-[a-z-]+|interactive-\d{3})\.png',p.name)):
                shutil.copyfile(p,output/p.name)
        retained={'run_id':run_id,'status':status,'engine':version,'engine_sha256':ENGINE_SHA,
                  'public_commit':os.environ.get('GITHUB_SHA'),'fixture_scope':'fixed synthetic display adapter, no private model/persistence',
                  'source_sha256':{k:sha(v) for k,v in files.items()},'source_index':index,
                  'runner_sha256':sha(Path(__file__).read_bytes()),'probe_sha256':sha((ROOT/'plan_probe.gd').read_bytes()),
                  'project_sha256':sha(project.encode()),'scene_sha256':sha(scene.encode()),
                  'output_sha256':{p.name:sha(p.read_bytes()) for p in sorted(output.glob('*.png'))}}
        (output/'manifest.json').write_text(json.dumps(retained,indent=2)+'\n')
    print('Native display plan passed; no full-app, tablet or shared-3D acceptance.')

if __name__=='__main__':
    if '--verify-only' in sys.argv:
        files,index=sources();print('Verified',len(files),'display dependencies; two explicit adapters; no core/application source.')
    else: execute()
