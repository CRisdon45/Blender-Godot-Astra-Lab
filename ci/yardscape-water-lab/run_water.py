"""Authorized public one-frame water look-development probe."""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, shutil, struct, subprocess, sys

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT/"project"
OUTPUT=ROOT/"outputs"/"baseline-01"
PIN="4.7.1.stable.official.a13da4feb"
ENGINE_SHA="32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"
APPLICATION_SOURCE_COMMIT="5538bd49cf4c32673e7e48fb70532f88a2da51a3"
ALLOWED={
 "project.godot","main.tscn","water_lab.gd",
 "shaders/basin.gdshader","shaders/water_surface.gdshader",
 "shaders/basin_fast.gdshader","shaders/water_surface_fast.gdshader",
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
    if OUTPUT.exists(): shutil.rmtree(OUTPUT)
    OUTPUT.mkdir(parents=True)

    capture=OUTPUT/"01-t000-full.png"
    env={k:v for k,v in os.environ.items() if not k.startswith(("PLAN_TRACE_","YARDSCAPE_","GODOT_MCP_"))}
    env.update(
        YARDSCAPE_WATER_TIME="0.00",
        YARDSCAPE_WATER_CAUSTICS="1",
        YARDSCAPE_WATER_SURFACE="1",
        YARDSCAPE_WATER_CAPTURE=str(capture.resolve()),
        LIBGL_ALWAYS_SOFTWARE="1",
        GODOT_SILENCE_ROOT_WARNING="1",
    )
    cmd=["xvfb-run","-a",str(engine),"--path",str(stage),"--audio-driver","Dummy"]
    proc=subprocess.run(cmd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,check=False)
    log=proc.stdout
    (OUTPUT/"console.log").write_text(log)
    print(log[-16000:])
    if proc.returncode!=0 or re.search(r"SCRIPT ERROR:|SHADER ERROR:|Parse Error|ERROR:",log):
        raise RuntimeError("Native full-water first look failed")
    if not capture.exists(): raise FileNotFoundError("Scene exited without capture")
    dims=png_dimensions(capture)
    if dims!=(480,360): raise ValueError("Unexpected capture size "+str(dims))
    if capture.stat().st_size<10000: raise ValueError("Suspiciously small capture")

    manifest={
      "schema":"yardscape-water-first-look/1",
      "application_source_commit":APPLICATION_SOURCE_COMMIT,
      "public_source_commit":os.environ.get("GITHUB_SHA"),
      "engine":version,
      "engine_sha256":ENGINE_SHA,
      "renderer":"Godot Compatibility / OpenGL",
      "viewport":[480,360],
      "state":{"time":0.0,"caustics":True,"surface":True},
      "source_sha256":source_hashes,
      "capture":{"file":capture.name,"sha256":sha(capture),"bytes":capture.stat().st_size},
      "artistic_acceptance":"not_reviewed",
      "limits":["Software llvmpipe worker, not target Android/tablet GPU","First-look full-water frame only"],
    }
    (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(json.dumps({"passed":True,"capture":capture.name,"bytes":capture.stat().st_size,"sha256":sha(capture)}))

if __name__=="__main__": main()
