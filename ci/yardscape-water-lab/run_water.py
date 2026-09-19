"""Authorized public water-only renderer probe."""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, shutil, struct, subprocess, sys, uuid

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT/"project"
OUTPUT=ROOT/"outputs"/"baseline-01"
PIN="4.7.1.stable.official.a13da4feb"
ENGINE_SHA="32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"
APPLICATION_SOURCE_COMMIT="6655e80c3e8e4d314dc2e9831b284971a6d0f52e"
ALLOWED={
 "project.godot","main.tscn","water_lab.gd",
 "shaders/basin.gdshader","shaders/water_surface.gdshader",
 "tests/water_matrix.gd",
}

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def png_dimensions(path):
    data=path.read_bytes()
    if len(data)<24 or data[:8]!=b"\x89PNG\r\n\x1a\n": raise ValueError("Not PNG "+str(path))
    return struct.unpack(">II",data[16:24])

def verify_source():
    actual={p.relative_to(PROJECT).as_posix() for p in PROJECT.rglob("*") if p.is_file() and ".godot" not in p.parts}
    if actual!=ALLOWED: raise ValueError("Unexpected source set "+str(sorted(actual^ALLOWED)))
    for name in sorted(actual):
        n=PurePosixPath(name)
        if n.is_absolute() or ".." in n.parts: raise ValueError("Invalid path "+name)
        p=PROJECT/name
        if p.is_symlink(): raise ValueError("Symlink "+name)
        text=p.read_text()
        if re.search(r"https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|res://(?:core|application)/|PLAN_TRACE_WORKSPACE_FILE",text):
            raise ValueError("Unexpected private/network dependency "+name)
        for ref in re.findall(r'res://([^\s\"\')]+)',text):
            if ref.endswith((".gd",".gdshader",".tscn")) and ref not in actual:
                raise ValueError("Unresolved "+ref)
    for name in actual:
        if name.endswith(".gdshader"):
            code=re.sub(r"//[^\n]*","",(PROJECT/name).read_text())
            if re.search(r"\bTIME\b|hint_screen_texture|hint_depth_texture|SCREEN_UV",code):
                raise ValueError("Unreviewed temporal/screen dependency "+name)
    return {name:sha(PROJECT/name) for name in sorted(actual)}

def main():
    source_hashes=verify_source()
    if "--verify-only" in sys.argv:
        print("Reviewed minimal water slice and resource closure verified"); return
    if os.environ.get("GITHUB_ACTIONS")!="true" or sys.platform!="linux":
        raise RuntimeError("Native execution only on authorized Linux GitHub worker")
    engine=Path(os.environ["GODOT_BIN"]).resolve()
    if sha(engine)!=ENGINE_SHA: raise ValueError("Pinned engine checksum mismatch")
    version=subprocess.run([str(engine),"--version"],text=True,capture_output=True,check=True,timeout=20).stdout.strip()
    if version!=PIN: raise ValueError("Version mismatch "+version)

    stage=Path(os.environ["RUNNER_TEMP"])/"northstar-water-lab"
    if stage.exists(): shutil.rmtree(stage)
    shutil.copytree(PROJECT,stage)
    inside=stage/".local"/"output"; inside.mkdir(parents=True)

    if OUTPUT.exists(): shutil.rmtree(OUTPUT)
    OUTPUT.mkdir(parents=True)

    run_id=str(uuid.uuid4())
    env={k:v for k,v in os.environ.items() if not k.startswith(("PLAN_TRACE_","YARDSCAPE_","GODOT_MCP_"))}
    env.update(
        YARDSCAPE_WATER_OUTPUT=str(inside),
        YARDSCAPE_WATER_RUN_ID=run_id,
        LIBGL_ALWAYS_SOFTWARE="1",
        GODOT_SILENCE_ROOT_WARNING="1",
    )
    cmd=["xvfb-run","-a",str(engine),"--path",str(stage),"--audio-driver","Dummy","--script","res://tests/water_matrix.gd"]
    proc=subprocess.run(cmd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300,check=False)
    log=proc.stdout
    print(log[-20000:])
    if proc.returncode!=0 or re.search(r"SCRIPT ERROR:|SHADER ERROR:|Parse Error|ERROR:",log):
        raise RuntimeError("Native water matrix failed")

    report=json.loads((inside/"report.json").read_text())
    if report.get("run_id")!=run_id or not report.get("passed") or report.get("failures"):
        raise RuntimeError("Missing, stale, or failed native report")
    pngs=sorted(inside.glob("*.png"))
    if len(pngs)!=9: raise ValueError("Expected nine PNGs, got "+str(len(pngs)))

    captures=[]
    for p in pngs:
        dims=png_dimensions(p)
        if dims!=(720,540): raise ValueError("Unexpected size "+p.name+" "+str(dims))
        if p.stat().st_size<20000: raise ValueError("Suspiciously small "+p.name)
        shutil.copyfile(p,OUTPUT/p.name)
        captures.append({"file":p.name,"sha256":sha(p),"bytes":p.stat().st_size,"dimensions":list(dims)})
    shutil.copyfile(inside/"report.json",OUTPUT/"report.json")

    full=[c["sha256"] for c in captures if "-full" in c["file"]]
    if len(full)!=3 or len(set(full))!=3: raise ValueError("Full-water frames are not three distinct states")

    manifest={
      "schema":"yardscape-water-baseline/1",
      "application_source_commit":APPLICATION_SOURCE_COMMIT,
      "public_source_commit":os.environ.get("GITHUB_SHA"),
      "engine":version,
      "engine_sha256":ENGINE_SHA,
      "adapter":report.get("adapter"),
      "renderer":report.get("renderer"),
      "viewport":[720,540],
      "camera":"fixed","sun":"fixed",
      "source_sha256":source_hashes,
      "captures":captures,
      "native_checks":len(report.get("checks",[])),
      "failures":report.get("failures",[]),
      "artistic_acceptance":"not_reviewed",
      "limits":[
        "Software llvmpipe worker, not target Android/tablet GPU",
        "No screen-space refraction or reflection in this baseline",
        "No coping, decking, plants, house, furniture, or app UI",
      ],
    }
    (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(json.dumps({"passed":True,"captures":len(captures),"native_checks":manifest["native_checks"],"adapter":manifest["adapter"]}))

if __name__=="__main__": main()
