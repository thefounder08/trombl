#!/usr/bin/env python3
"""Add dev/staging/prod iOS build configurations and Xcode schemes."""

from __future__ import annotations

import copy
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
SCHEMES_DIR = ROOT / "ios/Runner.xcodeproj/xcshareddata/xcschemes"

FLAVORS = {
    "dev": "trombl dev",
    "staging": "trombl staging",
    "prod": "trombl",
}

BASE_CONFIGS = {
    "project": {
        "Debug": "97C147031CF9000F007C117D",
        "Release": "97C147041CF9000F007C117D",
        "Profile": "249021D3217E4FDB00AE95B9",
    },
    "runner": {
        "Debug": "97C147061CF9000F007C117D",
        "Release": "97C147071CF9000F007C117D",
        "Profile": "249021D4217E4FDB00AE95B9",
    },
    "tests": {
        "Debug": "331C8088294A63A400263BE5",
        "Release": "331C8089294A63A400263BE5",
        "Profile": "331C808A294A63A400263BE5",
    },
}

XCCONFIG_BASE = {
    "Debug": "9740EEB21CF90195004384FC",
    "Release": "7AFA3C8E1D35360C0083082E",
    "Profile": "7AFA3C8E1D35360C0083082E",
}

PODS_TESTS_BASE = {
    "Debug": "9412FA283C1BAB6716279102",
    "Release": "4C7DD86E12D78C60F272F2B2",
    "Profile": "E7D7D3B024551D3DD0179DEB",
}


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def extract_block(text: str, obj_id: str) -> str:
    pattern = rf"\t\t{obj_id} /\* .+ \*/ = \{{\n.*?\n\t\t\}};"
    match = re.search(pattern, text, flags=re.DOTALL)
    if not match:
        raise RuntimeError(f"Could not find PBX object {obj_id}")
    return match.group(0)


def set_name(block: str, name: str) -> str:
    return re.sub(r"\n\t\t\tname = .+;\n", f"\n\t\t\tname = {name};\n", block, count=1)


def set_runner_display_name(block: str, display_name: str) -> str:
    if "INFOPLIST_KEY_CFBundleDisplayName" in block:
        return re.sub(
            r"INFOPLIST_KEY_CFBundleDisplayName = .+;",
            f'INFOPLIST_KEY_CFBundleDisplayName = "{display_name}";',
            block,
        )
    insert_before = "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER"
    return block.replace(
        insert_before,
        f'\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "{display_name}";\n{insert_before}',
    )


def write_flavor_xcconfig(flavor: str, build_type: str) -> str:
    flavor_dir = ROOT / "ios/Flutter/flavors"
    flavor_dir.mkdir(parents=True, exist_ok=True)
    lower = build_type.lower()
    file_name = f"{flavor}{build_type}.xcconfig"
    path = flavor_dir / file_name
    path.write_text(
        f'#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.{lower}-{flavor}.xcconfig"\n'
        f'#include "../{build_type}.xcconfig"\n',
        encoding="utf-8",
    )
    return file_name


def write_scheme(flavor: str) -> None:
    scheme_path = SCHEMES_DIR / f"{flavor}.xcscheme"
    scheme_path.write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97C146ED1CF9000F007C117D"
               BuildableName = "Runner.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug-{flavor}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      customLLDBInitFile = "$(SRCROOT)/Flutter/ephemeral/flutter_lldbinit"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "97C146ED1CF9000F007C117D"
         BuildableName = "Runner.app"
         BlueprintName = "Runner"
         ReferencedContainer = "container:Runner.xcodeproj">
      </BuildableReference>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug-{flavor}"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      customLLDBInitFile = "$(SRCROOT)/Flutter/ephemeral/flutter_lldbinit"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile-{flavor}"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug-{flavor}">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release-{flavor}"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""",
        encoding="utf-8",
    )


def main() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    if "Debug-dev" in text:
        print("iOS flavor configs already present; skipping pbxproj patch.")
    else:
        new_objects: list[str] = []
        new_file_refs: list[str] = []
        flavor_config_ids: dict[str, dict[str, dict[str, str]]] = {
            "project": {},
            "runner": {},
            "tests": {},
        }


        flutter_children_insert: list[str] = []

        for flavor, display_name in FLAVORS.items():
            flavor_config_ids["project"][flavor] = {}
            flavor_config_ids["runner"][flavor] = {}
            flavor_config_ids["tests"][flavor] = {}

            for build_type in ("Debug", "Release", "Profile"):
                config_name = f"{build_type}-{flavor}"

                for scope in ("project", "runner", "tests"):
                    base_id = BASE_CONFIGS[scope][build_type]
                    base_block = extract_block(text, base_id)
                    obj_id = new_id()
                    block = copy.deepcopy(base_block)
                    block = block.replace(base_id, obj_id, 1)
                    block = set_name(block, config_name)

                    if scope == "runner":
                        xcconfig_name = write_flavor_xcconfig(flavor, build_type)
                        file_ref_id = new_id()
                        new_file_refs.append(
                            f"\t\t{file_ref_id} /* {xcconfig_name} */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = {xcconfig_name}; path = Flutter/flavors/{xcconfig_name}; sourceTree = \"<group>\"; }};"
                        )
                        flutter_children_insert.append(
                            f"\t\t\t\t{file_ref_id} /* {xcconfig_name} */,"
                        )
                        block = re.sub(
                            r"baseConfigurationReference = [A-F0-9]+ /\* .+ \*/;",
                            f"baseConfigurationReference = {file_ref_id} /* {xcconfig_name} */;",
                            block,
                        )
                        block = set_runner_display_name(block, display_name)

                    flavor_config_ids[scope][flavor][build_type] = obj_id
                    new_objects.append(block)

        # Insert file references
        text = text.replace(
            "/* End PBXFileReference section */",
            "\n".join(new_file_refs) + "\n/* End PBXFileReference section */",
        )

        # Insert Flutter group children
        marker = "9740EEB11CF90186004384FC /* Flutter */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
        idx = text.find(marker)
        if idx == -1:
            raise RuntimeError("Could not find Flutter PBXGroup")
        insert_at = idx + len(marker)
        text = (
            text[:insert_at]
            + "\n".join(flutter_children_insert)
            + "\n"
            + text[insert_at:]
        )

        # Insert build configuration objects
        text = text.replace(
            "/* End XCBuildConfiguration section */",
            "\n".join(new_objects) + "\n/* End XCBuildConfiguration section */",
        )

        # Append to configuration lists
        def extend_config_list(list_id: str, scope: str) -> None:
            nonlocal text
            entries = []
            for flavor in FLAVORS:
                for build_type in ("Debug", "Release", "Profile"):
                    obj_id = flavor_config_ids[scope][flavor][build_type]
                    entries.append(
                        f"\t\t\t\t{obj_id} /* {build_type}-{flavor} */,"
                    )
            pattern = rf"({list_id} /\* Build configuration list .+ \*/ = \{{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = \(\n)(.*?)(\n\t\t\t\);)"
            match = re.search(pattern, text, flags=re.DOTALL)
            if not match:
                raise RuntimeError(f"Could not find config list {list_id}")
            replacement = match.group(1) + match.group(2) + "\n" + "\n".join(entries) + match.group(3)
            text = text[: match.start()] + replacement + text[match.end() :]

        extend_config_list("97C146E91CF9000F007C117D", "project")
        extend_config_list("97C147051CF9000F007C117D", "runner")
        extend_config_list("331C8087294A63A400263BE5", "tests")

        PBXPROJ.write_text(text, encoding="utf-8")
        print(f"Patched {PBXPROJ}")

    for flavor in FLAVORS:
        write_scheme(flavor)
        print(f"Wrote scheme {flavor}.xcscheme")


if __name__ == "__main__":
    main()
