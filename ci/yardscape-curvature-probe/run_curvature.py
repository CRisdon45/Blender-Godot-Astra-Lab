"""Bounded public curvature experiment. Native execution only on GitHub Linux."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
PREVIOUS=ROOT.parent/'yardscape-canopy-probe'
SPATIAL=ROOT.parent/'yardscape-spatial-probe'
PIN='4.7.1.stable.official.a13da4feb'
ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('previous_verify',PREVIOUS/'run_canopy.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    previous,spatial=module.verify()
    manifest=json.loads((ROOT/'source_manifest.json').read_text())
    files=set(manifest['sources'])
    actual={p.relative_to(ROOT/'project').as_posix() for p in (ROOT/'project').rglob('*') if p.is_file()}
    if actual!=files:raise ValueError('Unexpected source expansion')
    for name,record in manifest['sources'].items():
        p=ROOT/'project'/name
        if p.is_symlink() or '..' in Path(name).parts or sha(p)!=record['sha256']:raise ValueError('Source mismatch '+name)
        text=p.read_text()
        if re.search(r'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',text):raise ValueError('Forbidden dependency '+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if not any((d/'project'/ref).is_file() for d in (ROOT,PREVIOUS,SPATIAL)):raise ValueError('Unresolved '+ref)
    return manifest,previous,spatial

def run(full=False):
    manifest,previous,spatial=verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Native execution restricted to public Linux worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/('curvature-full' if full else 'curvature-look')
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(SPATIAL/'project',stage)
    for directory in (PREVIOUS,ROOT):
        for p in (directory/'project').rglob('*'):
            if p.is_file():
                dest=stage/p.relative_to(directory/'project');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
    if full:
        # Original assertions/thresholds preserved. Only select the new opt-in
        # scene, subclass, and generator in the staged copy, not the old seed tests.
        probe=(PREVIOUS/'canopy_probe.gd').read_text()
        replacements={'res://presentation/northstar/spatial_canopy_study.gd':'res://presentation/northstar/spatial_curved_canopy_study.gd',
                      'res://presentation/northstar/canopy/illustrative_tree.gd':'res://presentation/northstar/canopy/curved_tree.gd',
                      'res://northstar-spatial-canopy.tscn':'res://northstar-spatial-curved-canopy.tscn'}
        for old,new in replacements.items():
            if probe.count(old)!=1:raise ValueError('Unexpected upstream probe structure')
            probe=probe.replace(old,new)
    else:probe=(ROOT/'quick_probe.gd').read_text()
    (stage/'tests/curvature_probe.gd').write_text(probe)
    (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Public curvature comparison"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    inside=stage/'.local/output';inside.mkdir(parents=True)
    out=Path(os.environ['RUNNER_TEMP'])/('curvature-full-evidence' if full else 'curvature-look-evidence');out.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_CANOPY_OUTPUT=str(inside),YARDSCAPE_CANOPY_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/curvature_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/curvature_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):raise ValueError('Failed or stale report')
        if not report.get('adapter') or report['adapter']=='Dummy':raise ValueError('No real framebuffer')
        if len(list(inside.glob('*.png')))!=(27 if full else 8):raise ValueError('Unexpected capture count')
        status='passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'(?:\d\d-[a-z-]+|motion-\d\d)\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest.update(status=status,full_probe=full,run_id=run_id,public_commit=os.environ.get('GITHUB_SHA'),engine=version,engine_sha256=ENGINE_SHA,
                        previous_sources=previous['sources'],spatial_sources=spatial['sources'],runner_sha256=sha(Path(__file__)),
                        probe_sha256=hashlib.sha256(probe.encode()).hexdigest(),output_sha256={p.name:sha(p) for p in sorted(out.glob('*.png'))})
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Curvature sources and retained dependencies verified')
    else:run('--full' in sys.argv)
