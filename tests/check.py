#!/usr/bin/env python3
"""Run the Godot UI tests, then open a page of before-and-after screenshots.

The phone save is copied off Jwu 16 first and put back when the run finishes.
The Mac editor save is left alone; tests write a separate throwaway folder.
"""

from __future__ import annotations

import hashlib
import html
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
SAVE = Path.home() / "Library/Application Support/Godot/app_userdata/Sunflower Alarm/sunflower_alarms.json"
TEST_SAVE_DIR = Path.home() / "Library/Application Support/Godot/app_userdata/Sunflower Alarm Test"
REPORT = ROOT / "test-report"
ADDON = ROOT / "addons" / "gdUnit4"
GDUNIT_VERSION = "v6.2.2"
GDUNIT_URL = f"https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/{GDUNIT_VERSION}.tar.gz"
PHONE_UDID = "00008140-000A29502E8B001C"
PHONE_NAME = "Jwu 16"
BUNDLE = "com.xinli.sunflower"
PHONE_SAVE = "Documents/sunflower_alarms.json"


def digest(path: Path):
    if not path.is_file():
        return None
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ensure_addon() -> None:
    if (ADDON / "bin" / "GdUnitCmdTool.gd").is_file():
        return
    print(f"下载 gdUnit4 {GDUNIT_VERSION}")
    ADDON.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as download:
        archive = Path(download) / "gdunit.tar.gz"
        urllib.request.urlretrieve(GDUNIT_URL, archive)
        with tarfile.open(archive) as packed:
            packed.extractall(download)
        extracted = next(Path(download).glob("gdUnit4-*/addons/gdUnit4"))
        shutil.copytree(extracted, ADDON)


def test_project(tmp: Path) -> None:
    for child in ROOT.iterdir():
        if child.name in {"project.godot", ".godot", ".git"}:
            continue
        os.symlink(child, tmp / child.name)
    text = (ROOT / "project.godot").read_text()
    text = text.replace(
        'config/name="Sunflower Alarm"',
        'config/name="Sunflower Alarm Test"',
        1,
    )
    if 'config/name="Sunflower Alarm Test"' not in text:
        raise SystemExit("测试工程的名字没有换掉，已停止，避免写到真正的闹钟存档。")
    (tmp / "project.godot").write_text(text)
    godot_cache = ROOT / ".godot"
    if godot_cache.is_dir():
        shutil.copytree(godot_cache, tmp / ".godot", symlinks=True, ignore=shutil.ignore_patterns("*.lock"))
        cache = tmp / ".godot" / "global_script_class_cache.cfg"
        cache.unlink(missing_ok=True)


def phone_ready() -> bool:
    listed = subprocess.run(
        ["xcrun", "devicectl", "list", "devices"],
        capture_output=True,
        text=True,
    )
    for line in listed.stdout.splitlines():
        if PHONE_UDID in line and "available" in line:
            return True
    return False


def copy_phone(source: str, destination: str) -> subprocess.CompletedProcess:
    direction = "from" if source.startswith("Documents/") else "to"
    return subprocess.run(
        [
            "xcrun", "devicectl", "device", "copy", direction,
            "--device", PHONE_UDID,
            "--domain-type", "appDataContainer",
            "--domain-identifier", BUNDLE,
            "--source", source,
            "--destination", destination,
            "--timeout", "60",
        ],
        capture_output=True,
        text=True,
    )


def backup_phone(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    copied = copy_phone(PHONE_SAVE, str(dest))
    if copied.returncode != 0 or not dest.is_file():
        detail = (copied.stderr or copied.stdout or "").strip()
        raise SystemExit(f"没能从 {PHONE_NAME} 拷出闹钟数据，测试没有开始。\n{detail}")
    print(f"已备份 {PHONE_NAME} 上的闹钟数据。", flush=True)


def restore_phone(src: Path) -> bool:
    copied = copy_phone(str(src), PHONE_SAVE)
    if copied.returncode != 0:
        print((copied.stderr or copied.stdout or "").strip(), file=sys.stderr)
        return False
    check = src.with_name("restored.json")
    fetched = copy_phone(PHONE_SAVE, str(check))
    if fetched.returncode != 0 or not check.is_file():
        return False
    return digest(src) == digest(check)


def publish_report() -> Path | None:
    shots = TEST_SAVE_DIR / "shots"
    steps_path = shots / "steps.json"
    if not steps_path.is_file():
        return None
    if REPORT.exists():
        shutil.rmtree(REPORT)
    shutil.copytree(shots, REPORT)
    steps = json.loads((REPORT / "steps.json").read_text())
    stories = []
    for step in steps:
        if not stories or stories[-1]["title"] != step["story"]:
            stories.append({"title": step["story"], "frames": []})
        stories[-1]["frames"].append(step)
    parts = []
    for story in stories:
        frames = []
        for index, frame in enumerate(story["frames"]):
            if index:
                frames.append('<div class="arrow">→</div>')
            frames.append(
                "<figure>"
                f'<img src="{html.escape(frame["file"])}" alt="{html.escape(frame["caption"])}">'
                f"<figcaption>{html.escape(frame['caption'])}</figcaption>"
                "</figure>"
            )
        parts.append(
            "<section>"
            f"<h2>{html.escape(story['title'])}</h2>"
            f'<div class="reel">{"".join(frames)}</div>'
            "</section>"
        )
    page = REPORT / "index.html"
    page.write_text(
        """<!DOCTYPE html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<title>小小花闹钟测试</title>
<style>
  body { margin: 0; background: #d7e6f0; color: #1d3344;
    font-family: -apple-system, "PingFang SC", sans-serif; }
  header { padding: 28px 32px 8px; }
  h1 { margin: 0 0 6px; font-size: 28px; font-weight: 650; }
  header p { margin: 0; color: #4d687c; }
  section { padding: 8px 32px 28px; }
  h2 { margin: 18px 0 12px; font-size: 18px; }
  .reel { display: flex; align-items: center; gap: 8px; overflow-x: auto;
    padding-bottom: 8px; }
  figure { margin: 0; flex: 0 0 auto; }
  img { width: 220px; height: auto; display: block; background: white;
    border-radius: 22px; box-shadow: 0 10px 28px rgba(40, 70, 100, 0.18); }
  figcaption { width: 220px; margin-top: 8px; font-size: 14px; line-height: 1.4; }
  .arrow { flex: 0 0 auto; font-size: 28px; color: #3d6f92; padding: 0 4px 36px; }
</style>
</head>
<body>
<header>
  <h1>一次操作，一个状态</h1>
  <p>从左到右看。右边是左边做完之后的样子。</p>
</header>
"""
        + "\n".join(parts)
        + "\n</body>\n</html>\n"
    )
    return page


def main() -> int:
    if not GODOT.is_file():
        print(f"找不到 Godot：{GODOT}", file=sys.stderr)
        return 1
    if not phone_ready():
        print(f"{PHONE_NAME} 没连上，测试没有开始。", file=sys.stderr)
        return 1
    before = digest(SAVE)
    snapshot = SAVE.read_bytes() if SAVE.is_file() else None
    phone_dir = Path(tempfile.mkdtemp(prefix="sunflower-phone-"))
    phone_file = phone_dir / "sunflower_alarms.json"
    backed_up = False
    ensure_addon()
    tmp = Path(tempfile.mkdtemp(prefix="sunflower-gdunit-"))
    code = 1
    try:
        backup_phone(phone_file)
        backed_up = True
        test_project(tmp)
        imported = subprocess.run(
            [str(GODOT), "--headless", "--path", str(tmp), "--import", "--quit"],
            capture_output=True,
            text=True,
        )
        if imported.returncode != 0:
            sys.stdout.write(imported.stdout)
            sys.stderr.write(imported.stderr)
            raise subprocess.CalledProcessError(imported.returncode, imported.args)
        completed = subprocess.run(
            [
                str(GODOT),
                "--path",
                str(tmp),
                "-s",
                "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                "-a",
                "res://tests",
                "-c",
                *sys.argv[1:],
            ]
        )
        code = completed.returncode
    finally:
        if backed_up:
            if restore_phone(phone_file):
                print(f"已把闹钟数据放回 {PHONE_NAME}。", flush=True)
                shutil.rmtree(phone_dir, ignore_errors=True)
            else:
                print(f"放回 {PHONE_NAME} 失败。备份还在 {phone_file}", file=sys.stderr)
                code = 1
        after = digest(SAVE)
        if after != before:
            if snapshot is None:
                SAVE.unlink(missing_ok=True)
            else:
                SAVE.write_bytes(snapshot)
            print("电脑上的闹钟存档在测试期间变过，已经按开跑前的样子放回去。", flush=True)
        page = publish_report()
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(TEST_SAVE_DIR, ignore_errors=True)
        if page:
            subprocess.run(["open", str(page)])
            print(f"测试过程：{page}")
    if code == 0:
        print("测试通过。")
    else:
        print("测试没有通过。")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
