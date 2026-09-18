#!/usr/bin/env python3
"""Install the exact official export templates for the retained Godot build."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import urllib.request
import zipfile

VERSION = "4.7.1-stable"
TEMPLATE_DIR = "4.7.1.stable"
ARCHIVE_NAME = "Godot_v4.7.1-stable_export_templates.tpz"


def install() -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("CI-only installer; use an existing matching template set locally")
    work = Path(os.environ["RUNNER_TEMP"]) / "godot-export-templates"
    work.mkdir(exist_ok=False)
    request = urllib.request.Request(
        f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{VERSION}",
        headers={"User-Agent": "Yard-Scape-CI"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        metadata = json.load(response)
    asset = next(item for item in metadata["assets"] if item["name"] == ARCHIVE_NAME)
    expected = asset.get("digest", "")
    if not expected.startswith("sha256:"):
        raise RuntimeError("Official export-template archive digest missing")
    archive = work / ARCHIVE_NAME
    with urllib.request.urlopen(asset["browser_download_url"], timeout=180) as response:
        archive.write_bytes(response.read())
    actual = "sha256:" + hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError("Official export-template archive digest mismatch")
    destination = Path.home() / ".local/share/godot/export_templates" / TEMPLATE_DIR
    destination.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            source = PurePosixPath(member.filename)
            if not source.parts or source.parts[0] != "templates":
                raise RuntimeError(f"Unexpected template archive member: {member.filename}")
            relative = source.relative_to("templates")
            if not relative.parts:
                continue
            if ".." in relative.parts or stat.S_ISLNK(member.external_attr >> 16):
                raise RuntimeError(f"Unsafe template archive member: {member.filename}")
            target = destination.joinpath(*relative.parts)
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(package.read(member))
    required = {"android_debug.apk", "android_release.apk", "version.txt"}
    missing = sorted(name for name in required if not (destination / name).is_file())
    if missing:
        raise RuntimeError(f"Missing expected Android export templates: {missing}")
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
        env.write(f"GODOT_TEMPLATE_ARCHIVE_SHA256={actual.removeprefix('sha256:')}\n")
        env.write(f"GODOT_TEMPLATE_DIR={destination}\n")
    print(json.dumps({"archive": ARCHIVE_NAME, "sha256": actual, "destination": str(destination)}))


if __name__ == "__main__":
    install()
