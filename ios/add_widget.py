#!/usr/bin/env python3
"""Add the AlarmKit widget extension to a Godot-exported Xcode project."""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "build" / "ios" / "Sunflower Alarm.xcodeproj" / "project.pbxproj"
APP = ROOT / "build" / "ios" / "Sunflower Alarm"
WIDGET_SRC = ROOT / "ios" / "widget"


def main() -> None:
    global PROJECT, APP
    if len(sys.argv) > 1:
        xcode = Path(sys.argv[1])
        if not xcode.is_absolute():
            xcode = ROOT / xcode
        PROJECT = xcode / "project.pbxproj"
        APP = xcode.parent / xcode.name.removesuffix(".xcodeproj")
    dest = APP / "Widget"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy(WIDGET_SRC / "SunflowerAlarmWidget.swift", dest / "SunflowerAlarmWidget.swift")
    shutil.copy(WIDGET_SRC / "Info.plist", dest / "Info.plist")
    shutil.copy(WIDGET_SRC / "SunflowerAlarmWidget.entitlements", dest / "SunflowerAlarmWidget.entitlements")

    text = PROJECT.read_text()
    if "SunflowerAlarmWidget.swift" in text:
        print("widget already added")
        return

    text = text.replace(
        "\t\t\ttargets = (\n\t\t\t\tD0BCFE3318AEBDA2004A7AAE /* Sunflower Alarm */,\n\t\t\t);",
        "\t\t\ttargets = (\n\t\t\t\tD0BCFE3318AEBDA2004A7AAE /* Sunflower Alarm */,\n\t\t\t\tA10000000000000000000040 /* Sunflower Alarm Widget */,\n\t\t\t);",
    )
    text = text.replace(
        "\t\t\t\t90A13CD024AA68E500E8464F /* Embed Frameworks */,\n\t\t\t);",
        "\t\t\t\t90A13CD024AA68E500E8464F /* Embed Frameworks */,\n\t\t\t\tA10000000000000000000031 /* Embed Foundation Extensions */,\n\t\t\t);",
    )
    text = text.replace(
        "\t\t\tdependencies = (\n\t\t\t);",
        "\t\t\tdependencies = (\n\t\t\t\tA10000000000000000000042 /* PBXTargetDependency */,\n\t\t\t);",
    )
    text = text.replace(
        "\t\t\t\tD0BCFE3418AEBDA2004A7AAE /* Sunflower Alarm.app */,\n\t\t\t);",
        "\t\t\t\tD0BCFE3418AEBDA2004A7AAE /* Sunflower Alarm.app */,\n\t\t\t\tA10000000000000000000004 /* Sunflower Alarm Widget.appex */,\n\t\t\t);",
    )
    text = text.replace(
        "\t\t\t\t58938401000000000000000F\n\t\t\t);",
        "\t\t\t\t58938401000000000000000F,\n\t\t\t\tA10000000000000000000050 /* Widget */,\n\t\t\t);",
    )

    extra = r"""
/* Begin widget extension */
		A10000000000000000000011 /* SunflowerAlarmWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = A10000000000000000000001 /* SunflowerAlarmWidget.swift */; };
		A10000000000000000000012 /* sunflower.wav in Resources */ = {isa = PBXBuildFile; fileRef = 58938401000000000000000F /* sunflower.wav */; };
		A10000000000000000000013 /* SunflowerShared.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = 58938401000000000000000C /* SunflowerShared.xcframework */; };
		A10000000000000000000014 /* SunflowerShared.xcframework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = 58938401000000000000000C /* SunflowerShared.xcframework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };
		A10000000000000000000015 /* AlarmKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 589384010000000000000004 /* AlarmKit.framework */; };
		A10000000000000000000016 /* ActivityKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 589384010000000000000006 /* ActivityKit.framework */; };
		A10000000000000000000017 /* AppIntents.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 589384010000000000000008 /* AppIntents.framework */; };
		A10000000000000000000018 /* SwiftUI.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 58938401000000000000000A /* SwiftUI.framework */; };
		A10000000000000000000019 /* WidgetKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = A10000000000000000000005 /* WidgetKit.framework */; };
		A1000000000000000000001A /* Sunflower Alarm Widget.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = A10000000000000000000004 /* Sunflower Alarm Widget.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
		A10000000000000000000001 /* SunflowerAlarmWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SunflowerAlarmWidget.swift; sourceTree = "<group>"; };
		A10000000000000000000002 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		A10000000000000000000003 /* SunflowerAlarmWidget.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = SunflowerAlarmWidget.entitlements; sourceTree = "<group>"; };
		A10000000000000000000004 /* Sunflower Alarm Widget.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = "Sunflower Alarm Widget.appex"; sourceTree = BUILT_PRODUCTS_DIR; };
		A10000000000000000000005 /* WidgetKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; };
		A10000000000000000000020 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000000000000000000011 /* SunflowerAlarmWidget.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		A10000000000000000000021 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000000000000000000013 /* SunflowerShared.xcframework in Frameworks */,
				A10000000000000000000015 /* AlarmKit.framework in Frameworks */,
				A10000000000000000000016 /* ActivityKit.framework in Frameworks */,
				A10000000000000000000017 /* AppIntents.framework in Frameworks */,
				A10000000000000000000018 /* SwiftUI.framework in Frameworks */,
				A10000000000000000000019 /* WidgetKit.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		A10000000000000000000022 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000000000000000000012 /* sunflower.wav in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		A10000000000000000000023 /* Embed Frameworks */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 10;
			files = (
				A10000000000000000000014 /* SunflowerShared.xcframework in Embed Frameworks */,
			);
			name = "Embed Frameworks";
			runOnlyForDeploymentPostprocessing = 0;
		};
		A10000000000000000000031 /* Embed Foundation Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				A1000000000000000000001A /* Sunflower Alarm Widget.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};
		A10000000000000000000041 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = D0BCFE2C18AEBDA2004A7AAE /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = A10000000000000000000040;
			remoteInfo = "Sunflower Alarm Widget";
		};
		A10000000000000000000042 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = A10000000000000000000040 /* Sunflower Alarm Widget */;
			targetProxy = A10000000000000000000041 /* PBXContainerItemProxy */;
		};
		A10000000000000000000050 /* Widget */ = {
			isa = PBXGroup;
			children = (
				A10000000000000000000001 /* SunflowerAlarmWidget.swift */,
				A10000000000000000000002 /* Info.plist */,
				A10000000000000000000003 /* SunflowerAlarmWidget.entitlements */,
			);
			path = "Sunflower Alarm/Widget";
			sourceTree = "<group>";
		};
		A10000000000000000000040 /* Sunflower Alarm Widget */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A10000000000000000000070 /* Build configuration list for PBXNativeTarget "Sunflower Alarm Widget" */;
			buildPhases = (
				A10000000000000000000020 /* Sources */,
				A10000000000000000000021 /* Frameworks */,
				A10000000000000000000022 /* Resources */,
				A10000000000000000000023 /* Embed Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "Sunflower Alarm Widget";
			productName = "Sunflower Alarm Widget";
			productReference = A10000000000000000000004 /* Sunflower Alarm Widget.appex */;
			productType = "com.apple.product-type.app-extension";
		};
		A10000000000000000000060 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				CODE_SIGN_ENTITLEMENTS = "Sunflower Alarm/Widget/SunflowerAlarmWidget.entitlements";
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_TEAM = 0000000000;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "Sunflower Alarm/Widget/Info.plist";
				CURRENT_PROJECT_VERSION = 1.0.0;
				INFOPLIST_KEY_CFBundleDisplayName = "向日葵闹钟";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sunflower.alarm.widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		A10000000000000000000061 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				APPLICATION_EXTENSION_API_ONLY = YES;
				CODE_SIGN_ENTITLEMENTS = "Sunflower Alarm/Widget/SunflowerAlarmWidget.entitlements";
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_TEAM = 0000000000;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "Sunflower Alarm/Widget/Info.plist";
				CURRENT_PROJECT_VERSION = 1.0.0;
				INFOPLIST_KEY_CFBundleDisplayName = "向日葵闹钟";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.sunflower.alarm.widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
		A10000000000000000000070 /* Build configuration list for PBXNativeTarget "Sunflower Alarm Widget" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				A10000000000000000000060 /* Debug */,
				A10000000000000000000061 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End widget extension */
"""
    text = text.replace("/* End PBXProject section */", "/* End PBXProject section */\n" + extra)
    if "A10000000000000000000040 /* Sunflower Alarm Widget */" not in text.split("targets =", 1)[-1][:400]:
        raise SystemExit("failed to insert widget target into the project")
    PROJECT.write_text(text)
    print("widget added")


if __name__ == "__main__":
    main()
