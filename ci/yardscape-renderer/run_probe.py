"""Run only the approved public component in native Godot on GitHub Actions."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys, uuid
ROOT = Path(__file__).resolve().parent
PIN = '4.7.1.stable.official.a13da4feb'
ENGINE_SHA = '32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def verify_sources():
    manifest=json.loads((ROOT/'source_manifest.json').read_text())
    project=ROOT/'project'
    expected=set(manifest['source_sha256']) | {'project.godot','tests/receiver_probe.gd'}
    actual={str(p.relative_to(project)) for p in project.rglob('*') if p.is_file()}
    if actual != expected: raise ValueError('Unexpected or missing file in public slice')
    for name,wanted in manifest['source_sha256'].items():
        p=project/name
        if p.is_symlink() or sha(p)!=wanted: raise ValueError('Source identity mismatch: '+name)
    for p in project.rglob('*'):
        if p.is_symlink(): raise ValueError('Symlink not allowed')
        if not p.is_file(): continue
        text=p.read_text(encoding='utf-8')
        if re.search(r'(?:https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|drive\.google\.com)', text):
            raise ValueError('Unexpected network or credential-like content in renderer slice')
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith(('.gd','.gdshader','.gdshaderinc')) and not (project/ref).is_file():
                raise ValueError('Unresolved resource: '+ref)
    return manifest

def run():
    manifest=verify_sources()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':
        raise RuntimeError('Native execution is restricted to the authorized Linux GitHub worker')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA: raise ValueError('Pinned engine hash mismatch')
    version=subprocess.run([str(engine),'--version'],text=True,capture_output=True,timeout=20,check=True).stdout.strip()
    if version!=PIN: raise ValueError('Pinned engine version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'public-leaf-probe'
    if stage.exists(): raise FileExistsError('Fresh worker stage required')
    shutil.copytree(ROOT/'project',stage)
    inside=stage/'.local/output';inside.mkdir(parents=True)
    output=Path(os.environ['RUNNER_TEMP'])/'public-leaf-artifacts';output.mkdir(exist_ok=False)
    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_PUBLIC_OUTPUT=str(inside),YARDSCAPE_PUBLIC_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    commands=[('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/receiver_probe.gd','--check-only']),
              ('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/receiver_probe.gd'])]
    status='failed'
    try:
        for logname,command in commands:
            with (output/logname).open('w') as log:
                result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240,check=False)
            logtext=(output/logname).read_text(errors='replace')
            print(logtext[-12000:])
            if result.returncode or re.search(r'(?:SCRIPT ERROR:|SHADER ERROR:|ERROR:)',logtext):
                raise RuntimeError('Native check failed: '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=run_id or not report.get('passed') or report.get('failures'):
            raise RuntimeError('Missing, stale or failed component report')
        if not report.get('adapter') or report['adapter']=='Dummy': raise RuntimeError('No real framebuffer adapter')
        if len(list(inside.glob('*.png')))<14: raise RuntimeError('Expected captures missing')
        status='component_checks_passed'
    finally:
        # No original source kit, history, workspaces, environment dumps or references.
        for p in inside.iterdir():
            if p.name=='report.json' or (p.suffix=='.png' and re.fullmatch(r'\d\d-[a-z-]+\.png',p.name)):
                shutil.copyfile(p,output/p.name)
        manifest.update(run_id=run_id,status=status,engine_version=version,engine_sha256=ENGINE_SHA,
                        public_commit=os.environ.get('GITHUB_SHA'),runner_source_sha256=sha(Path(__file__)),
                        probe_sha256=sha(ROOT/'project/tests/receiver_probe.gd'),
                        output_sha256={p.name:sha(p) for p in sorted(output.glob('*.png'))})
        (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Public component proof complete; full application integration is not certified.')

if __name__=='__main__':
    if '--verify-only' in sys.argv:
        verify_sources();print('Public source identities and dependency allowlist passed')
    else:
        run()
