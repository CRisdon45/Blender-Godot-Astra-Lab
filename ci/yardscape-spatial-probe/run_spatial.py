"""Authorized public renderer-only native probe; no private-source access."""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    manifest=json.loads((ROOT/'source_manifest.json').read_text())
    project=ROOT/'project'
    expected=set(manifest['sources'])|{'tests/spatial_probe.gd'}
    actual={p.relative_to(project).as_posix() for p in project.rglob('*') if p.is_file()}
    if actual!=expected: raise ValueError('Unexpected public source expansion or missing file')
    for name,record in manifest['sources'].items():
        n=PurePosixPath(name)
        if n.is_absolute() or '..' in n.parts: raise ValueError('Invalid source path')
        p=project/name
        if p.is_symlink() or sha(p)!=record['sha256']:raise ValueError('Source mismatch '+name)
    for name in actual:
        p=project/name
        if p.is_symlink(): raise ValueError('Symlink is not permitted')
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/|PLAN_TRACE_WORKSPACE_FILE|FileAccess\.open\(draft',text):
            raise ValueError('Unexpected private/network dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith(('.gd','.gdshader','.tscn')) and ref not in actual:raise ValueError('Unresolved '+ref)
    # Stable procedural material domain: no time/screen texture or vertex displacement.
    for name in actual:
        if not name.endswith('.gdshader'): continue
        code=re.sub(r'//[^\n]*','', (project/name).read_text())
        if re.search(r'\b(TIME|SCREEN_UV|FRAGCOORD|EMISSION|hint_screen_texture|hint_depth_texture)\b|\bVERTEX\s*=',code):
            raise ValueError('Unreviewed material screen/time/emission/geometry dependency')
    return manifest

def run():
    manifest=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Native execution only on authorized Linux GitHub worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Pinned engine mismatch')
    version=subprocess.run([str(engine),'--version'],text=True,capture_output=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'spatial-material-probe'
    if stage.exists():raise FileExistsError('Fresh isolated stage required')
    shutil.copytree(ROOT/'project',stage)
    project='''config_version=5
[application]
config/name="Public spatial material witness"
run/main_scene="res://northstar-spatial-materials.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=900
[rendering]
renderer/rendering_method="gl_compatibility"
'''
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/'spatial-material-evidence';out.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_SPATIAL_OUTPUT=str(inside),YARDSCAPE_SPATIAL_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    cmds=[('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/spatial_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/spatial_probe.gd'])]
    status='failed'
    try:
        for logname,cmd in cmds:
            with (out/logname).open('w') as log:
                p=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=480,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if p.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):raise RuntimeError('Missing, stale or failed report')
        if not report.get('adapter') or report['adapter']=='Dummy':raise RuntimeError('Missing real framebuffer adapter')
        if len(list(inside.glob('*.png')))!=35:raise ValueError('Expected 19 comparisons plus 16 orbit poses')
        status='spatial_display_checks_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'(?:\d\d-[a-z-]+|orbit-\d\d)\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest.update(run_id=run_id,status=status,public_commit=os.environ.get('GITHUB_SHA'),engine=version,engine_sha256=ENGINE_SHA,
            runner_sha256=sha(Path(__file__)),probe_sha256=sha(ROOT/'project/tests/spatial_probe.gd'),project_sha256=hashlib.sha256(project.encode()).hexdigest(),
            output_sha256={p.name:sha(p) for p in sorted(out.glob('*.png'))})
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Native spatial renderer/material witness complete; private editing and tablet behavior remain untested.')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Reviewed spatial slice, shader domains and source hashes verified')
    else:run()
