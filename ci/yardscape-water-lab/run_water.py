"""Authorized public deterministic water comparison probe."""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, shutil, struct, subprocess, sys

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT/"project"
OUTPUT=ROOT/"outputs"/"iteration-06-surface-passages"
PIN="4.7.1.stable.official.a13da4feb"
ENGINE_SHA="32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"
APPLICATION_SOURCE_COMMIT="29460ab6b042a69c42172894bae99b25fb24e9a5"
ALLOWED={
 "project.godot","main.tscn","water_lab.gd",
 "shaders/basin_fast.gdshader","shaders/water_surface_fast.gdshader","shaders/wall_fast.gdshader",
 "tests/capture_first_look.gd","tests/capture_matrix.gd",
}
EXPECTED=[
 "01-t000-full.png",
 "02-t000-no-caustics.png",
 "03-t000-no-surface.png",
 "04-t175-full.png",
 "05-t400-full.png",
]

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
    if OUTPUT.exists(): shutil.rmtree(OUTPUT)
    OUTPUT.mkdir(parents=True)

    env={k:v for k,v in os.environ.items() if not k.startswith(("PLAN_TRACE_","YARDSCAPE_","GODOT_MCP_"))}
    env.update(
        YARDSCAPE_WATER_OUTPUT=str(OUTPUT.resolve()),
        LIBGL_ALWAYS_SOFTWARE="1",
        GODOT_SILENCE_ROOT_WARNING="1",
    )
    cmd=["xvfb-run","-a",str(engine),"--path",str(stage),"--audio-driver","Dummy","--script","res://tests/capture_matrix.gd"]
    try:
        proc=subprocess.run(cmd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=35,check=False)
        log=proc.stdout or ""
    except subprocess.TimeoutExpired as exc:
        log=exc.stdout or ""
        if isinstance(log,bytes): log=log.decode("utf-8","replace")
        (OUTPUT/"console.log").write_text(log)
        print(log[-20000:])
        raise RuntimeError("Godot water matrix timed out; preserved console.log") from exc
    (OUTPUT/"console.log").write_text(log)
    print(log[-20000:])
    if proc.returncode!=0 or re.search(r"SCRIPT ERROR:|SHADER ERROR:|Parse Error|ERROR:",log):
        raise RuntimeError("Native water matrix failed")

    actual={p.name for p in OUTPUT.glob("*.png")}
    if actual!=set(EXPECTED): raise ValueError("Expected five water PNGs, got "+str(sorted(actual)))
    captures=[]
    for name in EXPECTED:
        p=OUTPUT/name
        dims=png_dimensions(p)
        if dims!=(480,360): raise ValueError("Unexpected capture size "+name+" "+str(dims))
        if p.stat().st_size<5000: raise ValueError("Suspiciously small capture "+name)
        captures.append({"file":name,"sha256":sha(p),"bytes":p.stat().st_size,"dimensions":list(dims)})

    h={c["file"]:c["sha256"] for c in captures}
    if h["01-t000-full.png"]==h["02-t000-no-caustics.png"]: raise ValueError("Caustic toggle made no visible change")
    if h["01-t000-full.png"]==h["03-t000-no-surface.png"]: raise ValueError("Surface toggle made no visible change")
    if len({h["01-t000-full.png"],h["04-t175-full.png"],h["05-t400-full.png"]})!=3:
        raise ValueError("Water time did not produce three distinct full-water frames")

    manifest={
      "schema":"yardscape-water-matrix/1",
      "application_source_commit":APPLICATION_SOURCE_COMMIT,
      "public_source_commit":os.environ.get("GITHUB_SHA"),
      "engine":version,
      "engine_sha256":ENGINE_SHA,
      "renderer":"Godot Compatibility / OpenGL",
      "viewport":[480,360],
      "states":[
        {"file":"01-t000-full.png","time":0.0,"caustics":True,"surface":True},
        {"file":"02-t000-no-caustics.png","time":0.0,"caustics":False,"surface":True},
        {"file":"03-t000-no-surface.png","time":0.0,"caustics":True,"surface":False},
        {"file":"04-t175-full.png","time":1.75,"caustics":True,"surface":True},
        {"file":"05-t400-full.png","time":4.0,"caustics":True,"surface":True},
      ],
      "source_sha256":source_hashes,
      "captures":captures,
      "artistic_acceptance":"not_reviewed",
      "limits":["Software llvmpipe worker, not target Android/tablet GPU"],
    }
    (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(json.dumps({"passed":True,"captures":len(captures)}))

if __name__=="__main__": main()
