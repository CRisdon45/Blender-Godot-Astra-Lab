"""Reviewed public normal/shadow diagnostic. Native execution only on GitHub Linux."""
from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, uuid
ROOT = Path(__file__).resolve().parent
CURVE = ROOT.parent / 'yardscape-curvature-probe'
CANOPY = ROOT.parent / 'yardscape-canopy-probe'
SPATIAL = ROOT.parent / 'yardscape-spatial-probe'
PIN = '4.7.1.stable.official.a13da4feb'
ENGINE_SHA = '32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(data): return hashlib.sha256(data).hexdigest()
def prepare_sources():
    spec = importlib.util.spec_from_file_location('curve_verify', CURVE/'run_curvature.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    curve, canopy, spatial = module.verify()
    result = {}
    for directory, manifest in [(SPATIAL,spatial),(CANOPY,canopy),(CURVE,curve)]:
        for name, record in manifest['sources'].items():
            path = directory/'project'/name
            if path.is_symlink() or '..' in Path(name).parts: raise ValueError('Invalid source path')
            data = path.read_bytes()
            if sha(data) != record['sha256']: raise ValueError('Retained source mismatch')
            result[name] = data
    probe = (ROOT/'lighting_probe.gd').read_bytes()
    if re.search(rb'https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/',probe):
        raise ValueError('Unexpected private or network dependency in new probe')
    original = result['presentation/northstar/canopy/curved_tree.gd'].decode('utf-8')
    before = '_n.append(normal.lerp(guide,.56).normalized())'
    after = '_n.append(normal)'
    if original.count(before) != 1: raise ValueError('Normal substitution must have exactly one known match')
    analytic = original.replace(before,after).encode('utf-8')
    return result, probe, analytic

def run():
    files, probe, analytic = prepare_sources()
    if os.environ.get('GITHUB_ACTIONS') != 'true' or sys.platform != 'linux':
        raise RuntimeError('Native execution is restricted to the authorized public Linux worker')
    engine = Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine.read_bytes()) != ENGINE_SHA: raise ValueError('Pinned engine hash mismatch')
    version = subprocess.run([str(engine),'--version'],capture_output=True,text=True,timeout=20,check=True).stdout.strip()
    if version != PIN: raise ValueError('Pinned engine version mismatch')
    stage = Path(os.environ['RUNNER_TEMP'])/'lighting-diagnostic'
    stage.mkdir(exist_ok=False)
    for name,data in files.items():
        p = stage/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(data)
    (stage/'tests').mkdir(exist_ok=True)
    (stage/'tests/lighting_probe.gd').write_bytes(probe)
    inside = stage/'.local/output'; inside.mkdir(parents=True)
    (stage/'.local/diagnostic_analytic.gd').write_bytes(analytic)
    project = ('config_version=5\n[application]\nconfig/name="Public canopy lighting diagnostic"\n'
               '[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=900\n'
               '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (stage/'project.godot').write_text(project)
    output = Path(os.environ['RUNNER_TEMP'])/'lighting-evidence'; output.mkdir(exist_ok=False)
    run_id = str(uuid.uuid4())
    env = {k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))}
    env.update(YARDSCAPE_LIGHTING_OUTPUT=str(inside),YARDSCAPE_LIGHTING_RUN_ID=run_id,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1')
    status = 'failed'
    try:
        commands = [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/lighting_probe.gd','--check-only']),
                    ('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/lighting_probe.gd'])]
        for logname,command in commands:
            with (output/logname).open('w') as log:
                completed = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=480,check=False)
            text = (output/logname).read_text(errors='replace'); print(text[-16000:])
            if completed.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):
                raise RuntimeError('Native diagnostic failed: '+logname)
        report = json.loads((inside/'report.json').read_text())
        if report.get('run_id') != run_id or not report.get('passed') or report.get('failures'):
            raise ValueError('Missing, stale or failed diagnostic report')
        if not report.get('adapter') or report['adapter']=='Dummy': raise ValueError('No native framebuffer adapter')
        if len(list(inside.glob('*.png'))) != 51: raise ValueError('Expected 51 controlled diagnostic captures')
        status = 'passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'[A-Za-z0-9-]+\.png',p.name):
                shutil.copyfile(p,output/p.name)
        manifest = {'run_id':run_id,'status':status,'public_commit':os.environ.get('GITHUB_SHA'),
                    'engine':version,'engine_sha256':ENGINE_SHA,'source_sha256':{k:sha(v) for k,v in files.items()},
                    'probe_sha256':sha(probe),'runner_sha256':sha(Path(__file__).read_bytes()),
                    'analytic_variant_sha256':sha(analytic),'analytic_change':'one normal expression only; temporary staged file',
                    'project_sha256':sha(project.encode()),
                    'scope':'unchanged reviewed spatial adapters; normal arrays and receipt-only shader variants; no private editing/persistence',
                    'output_sha256':{p.name:sha(p.read_bytes()) for p in sorted(output.glob('*.png'))}}
        (output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Diagnostic complete; no production or tablet acceptance implied.')
if __name__ == '__main__':
    if '--verify-only' in sys.argv:
        files,probe,analytic=prepare_sources(); print('Verified',len(files),'retained dependencies and a one-expression analytic-normal variant')
    else: run()
