#!/usr/bin/env python3
"""CI-only, explicit installation of the retained engine, never used by previews."""
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.request
import zipfile

BINARY_HASHES = {
    "linux": ("Godot_v4.7.1-stable_linux.x86_64", "32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde"),
    "win32": ("Godot_v4.7.1-stable_win64.exe", "323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a"),
}


def archive_name_for(platform: str) -> str:
    return BINARY_HASHES[platform][0] + ".zip"


def install() -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("CI-only installer; use the existing pinned engine locally")
    filename, expected_binary = BINARY_HASHES[sys.platform]
    archive_name = archive_name_for(sys.platform)
    root = Path(os.environ["RUNNER_TEMP"]) / "godot"
    root.mkdir(exist_ok=False)
    request = urllib.request.Request(
        "https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.1-stable",
        headers={"User-Agent":"Yard-Scape-CI"})
    with urllib.request.urlopen(request, timeout=60) as response:
        metadata = json.load(response)
    asset = next(a for a in metadata["assets"] if a["name"] == archive_name)
    expected_archive = asset.get("digest", "")
    if not expected_archive.startswith("sha256:"):
        raise RuntimeError("Official archive digest missing")
    archive = root / archive_name
    with urllib.request.urlopen(asset["browser_download_url"], timeout=120) as response:
        archive.write_bytes(response.read())
    if "sha256:" + hashlib.sha256(archive.read_bytes()).hexdigest() != expected_archive:
        raise RuntimeError("Official archive digest mismatch")
    with zipfile.ZipFile(archive) as package:
        data = package.read(filename)
    if hashlib.sha256(data).hexdigest() != expected_binary:
        raise RuntimeError("Pinned engine binary changed")
    engine = root / filename
    engine.write_bytes(data)
    engine.chmod(0o755)
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
        env.write(f"GODOT_BIN={engine}\n")


if __name__ == "__main__":
    install()
