"""Authorized public water-only renderer probe.

This runner executes only the reviewed minimal water lab mirrored from Yard-Scape.
It generates a deterministic nine-image baseline and writes it into the public
branch's outputs folder so the results remain browsable after Actions artifacts expire.
"""
from pathlib import Path, PurePosixPath
import hashlib, json, os, re, shutil, struct, subprocess, sys

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / "project"
OUTPUT = ROOT / "outputs" / "baseline-01"
PIN = "4.7.1.stable.official.a13da4feb"
ENGINE_SHA = "32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"
APPLICATION_SOURCE_COMMIT = "90d3993571f26ffb267b7c99ebd529d5e9baf52b"

ALLOWED = {
    "project.godot",
    "main.tscn",
    "water_lab.gd",
    "shaders/basin.gdshader",
    "shaders/water_surface.gdshader",
}

STATES = [
    ("01-t000-full.png", 0.00, True, True),
    ("02-t000-no-caustics.png", 0.00, False, True),
    ("03-t000-no-surface.png", 0.00, True, False),
    ("04-t175-full.png", 1.75, True, True),
    ("05-t175-no-caustics.png", 1.75, False, True),
    ("06-t175-no-surface.png", 1.75, True, False),
    ("07-t400-full.png", 4.00, True, True),
    ("08-t400-no-caustics.png", 4.00, False, True),
    ("09-t400-no-surface.png", 4.00, True, False),
]

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def png_dimensions(path: Path):
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])

def verify_source():
    actual = {
        p.relative_to(PROJECT).as_posix()
        for p in PROJECT.rglob("*")
        if p.is_file() and ".godot" not in p.parts
    }
    if actual != ALLOWED:
        raise ValueError(f"Unexpected public source set: {sorted(actual ^ ALLOWED)}")

    for name in sorted(actual):
        n = PurePosixPath(name)
        if n.is_absolute() or ".." in n.parts:
            raise ValueError("Invalid source path " + name)
        p = PROJECT / name
        if p.is_symlink():
            raise ValueError("Symlink not permitted " + name)
        text = p.read_text()
        if re.search(
            r"https?://|BEGIN .*PRIVATE KEY|gh[pousr]_|github_pat_|sk-proj-|"
            r"res://(?:core|application)/|PLAN_TRACE_WORKSPACE_FILE|FileAccess\.open\(draft",
            text,
        ):
            raise ValueError("Unexpected private/network dependency " + name)
        for ref in re.findall(r'res://([^\s\"\')]+)', text):
            if ref.endswith((".gd", ".gdshader", ".tscn")) and ref not in actual:
                raise ValueError("Unresolved reviewed resource " + ref)

    # Water time is explicit and deterministic; shader TIME/screen/depth reads are
    # intentionally not part of this baseline.
    for name in actual:
        if not name.endswith(".gdshader"):
            continue
        code = re.sub(r"//[^\n]*", "", (PROJECT / name).read_text())
        if re.search(r"\bTIME\b|hint_screen_texture|hint_depth_texture|SCREEN_UV", code):
            raise ValueError("Unreviewed temporal/screen dependency " + name)

    return {name: sha(PROJECT / name) for name in sorted(actual)}

def main():
    source_hashes = verify_source()
    if "--verify-only" in sys.argv:
        print("Reviewed minimal water slice and resource closure verified")
        return
    if os.environ.get("GITHUB_ACTIONS") != "true" or sys.platform != "linux":
        raise RuntimeError("Native execution is restricted to the authorized Linux GitHub worker")

    engine = Path(os.environ["GODOT_BIN"]).resolve()
    if sha(engine) != ENGINE_SHA:
        raise ValueError("Pinned engine checksum mismatch")
    version = subprocess.run(
        [str(engine), "--version"],
        text=True,
        capture_output=True,
        check=True,
        timeout=20,
    ).stdout.strip()
    if version != PIN:
        raise ValueError("Pinned engine version mismatch: " + version)

    stage = Path(os.environ["RUNNER_TEMP"]) / "northstar-water-lab"
    if stage.exists():
        shutil.rmtree(stage)
    shutil.copytree(PROJECT, stage)

    if OUTPUT.exists():
        shutil.rmtree(OUTPUT)
    OUTPUT.mkdir(parents=True)

    base_env = {
        k: v for k, v in os.environ.items()
        if not k.startswith(("PLAN_TRACE_", "YARDSCAPE_", "GODOT_MCP_"))
    }
    base_env.update(
        LIBGL_ALWAYS_SOFTWARE="1",
        GODOT_SILENCE_ROOT_WARNING="1",
    )

    results = []
    adapter_line = ""
    for filename, time_value, caustics, surface in STATES:
        capture = OUTPUT / filename
        env = dict(base_env)
        env.update(
            YARDSCAPE_WATER_TIME=f"{time_value:.2f}",
            YARDSCAPE_WATER_CAUSTICS="1" if caustics else "0",
            YARDSCAPE_WATER_SURFACE="1" if surface else "0",
            YARDSCAPE_WATER_CAPTURE=str(capture),
        )
        cmd = [
            "xvfb-run", "-a", str(engine),
            "--path", str(stage),
            "--audio-driver", "Dummy",
        ]
        proc = subprocess.run(
            cmd,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=90,
            check=False,
        )
        log = proc.stdout
        print(f"--- {filename} ---\n{log[-12000:]}")
        if proc.returncode != 0 or re.search(r"SCRIPT ERROR:|SHADER ERROR:|Parse Error|ERROR:", log):
            raise RuntimeError(f"Native render failed for {filename}")
        if not capture.exists():
            raise FileNotFoundError("Missing capture " + filename)
        dims = png_dimensions(capture)
        if dims != (960, 720):
            raise ValueError(f"Unexpected PNG size {dims} for {filename}")
        if capture.stat().st_size < 20000:
            raise ValueError(f"Suspiciously small render {filename}: {capture.stat().st_size} bytes")
        if not adapter_line:
            for line in log.splitlines():
                if "OpenGL API" in line or "llvmpipe" in line:
                    adapter_line = line.strip()
                    break
        results.append({
            "file": filename,
            "time": time_value,
            "caustics": caustics,
            "surface": surface,
            "sha256": sha(capture),
            "bytes": capture.stat().st_size,
            "dimensions": list(dims),
        })

    by_file = {r["file"]: r for r in results}
    for prefix in ("t000", "t175", "t400"):
        full = next(r for r in results if prefix in r["file"] and "-full" in r["file"])
        no_c = next(r for r in results if prefix in r["file"] and "no-caustics" in r["file"])
        no_s = next(r for r in results if prefix in r["file"] and "no-surface" in r["file"])
        if full["sha256"] == no_c["sha256"]:
            raise ValueError("Caustic toggle made no framebuffer change at " + prefix)
        if full["sha256"] == no_s["sha256"]:
            raise ValueError("Surface toggle made no framebuffer change at " + prefix)

    full_hashes = [r["sha256"] for r in results if "-full" in r["file"]]
    if len(set(full_hashes)) != 3:
        raise ValueError("Explicit water time did not produce three distinct full-water frames")

    manifest = {
        "schema": "yardscape-water-baseline/1",
        "application_source_commit": APPLICATION_SOURCE_COMMIT,
        "public_source_commit": os.environ.get("GITHUB_SHA"),
        "engine": version,
        "engine_sha256": ENGINE_SHA,
        "adapter": adapter_line,
        "renderer": "Godot Compatibility / OpenGL",
        "viewport": [960, 720],
        "camera": "fixed",
        "sun": "fixed",
        "source_sha256": source_hashes,
        "captures": results,
        "artistic_acceptance": "not_reviewed",
        "limits": [
            "Software llvmpipe worker, not target Android/tablet GPU",
            "No screen-space refraction or reflection in this baseline",
            "No coping, decking, plants, house, furniture, or app UI",
            "Visual acceptance requires review of the committed PNGs",
        ],
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({
        "passed": True,
        "captures": len(results),
        "output": str(OUTPUT),
        "unique_pngs": len({r["sha256"] for r in results}),
    }))

if __name__ == "__main__":
    main()
