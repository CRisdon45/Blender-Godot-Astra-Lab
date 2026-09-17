from pathlib import Path
import hashlib, importlib.util, json, os, re, shutil, statistics, subprocess, sys, uuid
ROOT=Path(__file__).resolve().parent
BATCH=ROOT.parent/'yardscape-dab-batch-probe'
VALUE=ROOT.parent/'yardscape-dab-value-probe'
DABTREE=ROOT.parent/'yardscape-dab-tree-probe'
SPATIAL=ROOT.parent/'yardscape-spatial-probe'
CANOPY=ROOT.parent/'yardscape-canopy-probe'
GROUP=ROOT.parent/'yardscape-foliage-group-probe'
DAB=ROOT.parent/'yardscape-dab-group-probe'
COMPACT=ROOT.parent/'yardscape-compact-tree-probe'
PIN='4.7.1.stable.official.a13da4feb';ENGINE_SHA='32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
    spec=importlib.util.spec_from_file_location('batch_verify',BATCH/'run_batch.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.verify()
    return True
def summary(values):
    values=[float(v) for v in values if float(v)>=0]
    if not values:return {"n":0}
    s=sorted(values);n=len(s)
    return {"n":n,"median":statistics.median(s),"mean":statistics.fmean(s),"p10":s[int((n-1)*.10)],"p90":s[int((n-1)*.90)],"min":s[0],"max":s[-1]}
def combine(blocks,key):
    result=[]
    for b in blocks:result.extend(b[key])
    return result
def run():
    verify()
    if os.environ.get('GITHUB_ACTIONS')!='true' or sys.platform!='linux':raise RuntimeError('Remote worker only')
    engine=Path(os.environ['GODOT_BIN']).resolve()
    if sha(engine)!=ENGINE_SHA:raise ValueError('Engine mismatch')
    version=subprocess.run([str(engine),'--version'],capture_output=True,text=True,check=True,timeout=20).stdout.strip()
    if version!=PIN:raise ValueError('Version mismatch')
    stage=Path(os.environ['RUNNER_TEMP'])/'dab-benchmark'
    if stage.exists():raise FileExistsError('Fresh stage required')
    shutil.copytree(SPATIAL/'project',stage)
    for base in (CANOPY,GROUP,DAB,COMPACT,DABTREE,VALUE,BATCH):
        for p in (base/'project').rglob('*'):
            if p.is_file():
                dest=stage/p.relative_to(base/'project');dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
    shutil.copyfile(ROOT/'benchmark_probe.gd',stage/'tests/benchmark_probe.gd')
    project='''config_version=5
[application]
config/name="Repeated dab tree batching benchmark"
[display]
window/size/viewport_width=960
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
'''
    (stage/'project.godot').write_text(project)
    inside=stage/'.local/output';inside.mkdir(parents=True);out=Path(os.environ['RUNNER_TEMP'])/'dab-benchmark-evidence';out.mkdir(exist_ok=False)
    rid=str(uuid.uuid4());env={k:v for k,v in os.environ.items() if not k.startswith(('PLAN_TRACE_','YARDSCAPE_','GODOT_MCP_'))};env.update(YARDSCAPE_DAB_BENCH_OUTPUT=str(inside),YARDSCAPE_DAB_BENCH_RUN_ID=rid,LIBGL_ALWAYS_SOFTWARE='1',GODOT_SILENCE_ROOT_WARNING='1');status='failed'
    try:
        for logname,cmd in [('preflight.log',[str(engine),'--headless','--path',str(stage),'--script','res://tests/benchmark_probe.gd','--check-only']),('console.log',['xvfb-run','-a',str(engine),'--path',str(stage),'--audio-driver','Dummy','--script','res://tests/benchmark_probe.gd'])]:
            with (out/logname).open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600,check=False)
            text=(out/logname).read_text(errors='replace');print(text[-16000:])
            if r.returncode or re.search(r'SCRIPT ERROR:|SHADER ERROR:|ERROR:',text):raise RuntimeError('Native failure '+logname)
        report=json.loads((inside/'report.json').read_text())
        if report.get('run_id')!=rid or not report.get('passed') or report.get('failures'):raise RuntimeError('Failed report')
        summaries={}
        for count,data in report['measurements'].items():
            summaries[count]={}
            for kind in ('regular','batched'):
                blocks=data[kind]
                summaries[count][kind]={
                    "cpu_render_ms":summary(combine(blocks,'cpu_ms')),
                    "frame_setup_ms":summary(combine(blocks,'setup_ms')),
                    "gpu_reported_ms":summary(combine(blocks,'gpu_ms')),
                    "wall_frame_ms":summary(combine(blocks,'wall_ms')),
                    "counters":blocks[-1]['counters']
                }
            rmed=summaries[count]['regular']['cpu_render_ms'].get('median',0)
            bmed=summaries[count]['batched']['cpu_render_ms'].get('median',0)
            summaries[count]['cpu_median_ratio_batched_over_regular']=bmed/rmed if rmed>0 else None
        report['summary']=summaries
        (inside/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        status='benchmark_passed'
    finally:
        for p in inside.iterdir():
            if p.name=='report.json' or re.fullmatch(r'\d\d-[a-z0-9-]+\.png',p.name):shutil.copyfile(p,out/p.name)
        manifest={"status":status,"run_id":rid,"public_commit":os.environ.get('GITHUB_SHA'),"engine":version,"engine_sha256":ENGINE_SHA,"runner_sha256":sha(Path(__file__)),"output_sha256":{p.name:sha(p) for p in sorted(out.glob('*.png'))}}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':
    if '--verify-only' in sys.argv:verify();print('Repeated-tree benchmark dependency boundary verified')
    else:run()
