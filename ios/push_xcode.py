#!/usr/bin/env python3
"""Export the Godot project into the Xcode project, then put back the bits export wipes."""

import argparse
import filecmp
import plistlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
XCODE = ROOT / "build" / "ios" / "Sunflower Alarm.xcodeproj"
APP = ROOT / "build" / "ios" / "Sunflower Alarm"
TEAM = "CWYYTE33YX"
SAVE = Path.home() / "Library/Application Support/Godot/app_userdata/Sunflower Alarm/sunflower_alarms.json"


def install_settings(app: Path, project: Path) -> None:
    dest = app / "Settings.bundle"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(ROOT / "ios" / "Settings.bundle", dest)
    text = project.read_text()
    if "Settings.bundle" in text:
        return
    text = text.replace(
        "\t\t\t\t90B4C2B52680C7E90039117A /* dummy.swift */,\n",
        "\t\t\t\t90B4C2B52680C7E90039117A /* dummy.swift */,\n\t\t\t\tB10000000000000000000001 /* Settings.bundle */,\n",
    )
    text = text.replace(
        "\t\t\t\t58938401000000000000000E\n\t\t\t);",
        "\t\t\t\t58938401000000000000000E,\n\t\t\t\tB10000000000000000000002 /* Settings.bundle in Resources */,\n\t\t\t);",
    )
    text = text.replace(
        "/* End PBXFileReference section */",
        "\t\tB10000000000000000000001 /* Settings.bundle */ = {isa = PBXFileReference; lastKnownFileType = \"wrapper.plug-in\"; path = Settings.bundle; sourceTree = \"<group>\"; };\n/* End PBXFileReference section */",
    )
    text = text.replace(
        "/* End PBXBuildFile section */",
        "\t\tB10000000000000000000002 /* Settings.bundle in Resources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000001 /* Settings.bundle */; };\n/* End PBXBuildFile section */",
    )
    project.write_text(text)


def post_export(xcode: Path = XCODE) -> None:
    if not xcode.is_absolute():
        xcode = ROOT / xcode
    app = xcode.parent / xcode.name.removesuffix(".xcodeproj")
    subprocess.run(["python3", str(ROOT / "ios" / "add_widget.py"), str(xcode)], check=True)

    project = xcode / "project.pbxproj"
    project.write_text(project.read_text().replace("DEVELOPMENT_TEAM = 0000000000;", f"DEVELOPMENT_TEAM = {TEAM};"))

    info_path = app / "Sunflower Alarm-Info.plist"
    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    info["NSSupportsLiveActivities"] = True
    info["CFBundleURLTypes"] = [
        {
            "CFBundleURLName": "com.sunflower.alarm",
            "CFBundleURLSchemes": ["sunflower"],
        }
    ]
    for key in (
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSPhotoLibraryUsageDescription",
        "UIRequiresFullScreen",
    ):
        info.pop(key, None)
    with info_path.open("wb") as handle:
        plistlib.dump(info, handle)

    install_settings(app, project)

    launch = ROOT / "ios" / "launch"
    shutil.copy(launch / "Launch Screen.storyboard", app / "Launch Screen.storyboard")
    imageset = app / "Images.xcassets" / "SplashImage.imageset"
    if imageset.exists():
        shutil.rmtree(imageset)
    shutil.copytree(launch / "SplashImage.imageset", imageset)
    print("Xcode project is ready:", xcode)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--post-only", action="store_true")
    parser.add_argument("xcode", nargs="?", default=str(XCODE))
    args = parser.parse_args()
    xcode = Path(args.xcode)
    if args.post_only:
        post_export(xcode)
        return

    snapshot = SAVE.with_suffix(".push-snapshot.json")
    if SAVE.exists():
        shutil.copy(SAVE, snapshot)
    xcode.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(GODOT),
            "--headless",
            "--path",
            str(ROOT),
            "--export-debug",
            "iOS",
            str(xcode),
        ],
        check=True,
    )
    post_export(xcode)
    if snapshot.exists():
        if not SAVE.exists() or not filecmp.cmp(SAVE, snapshot, shallow=False):
            shutil.copy(snapshot, SAVE)
            print("alarm save restored")
        snapshot.unlink()


if __name__ == "__main__":
    main()
