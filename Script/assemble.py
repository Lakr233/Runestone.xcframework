#!/usr/bin/env python3
"""Flatten Runestone + Tree-sitter + languages + themes into one framework tree."""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
from pathlib import Path


SKIP_LANGUAGE_DIRS = {
    "RunestoneLanguageSupport",
    "TreeSitterLanguagesCommon",
}

COMBINED_QUERY_BLOCK = re.compile(
    r"\nprivate extension TreeSitterLanguage \{\n"
    r"    private static func combinedQuery\(fromFilesAt fileURLs: \[URL\]\) -> TreeSitterLanguage\.Query\? \{\n"
    r"        let rawQuery = fileURLs\.compactMap \{ try\? String\(contentsOf: \$0\) \}\.joined\(separator: \"\\n\"\)\n"
    r"        if !rawQuery\.isEmpty \{\n"
    r"            return TreeSitterLanguage\.Query\(string: rawQuery\)\n"
    r"        \} else \{\n"
    r"            return nil\n"
    r"        \}\n"
    r"    \}\n"
    r"\}\n?",
    re.MULTILINE,
)

NAMED_IN_MODULE_BLOCK = re.compile(
    r"\nprivate extension UIColor \{\n"
    r"    convenience init\(namedInModule name: String\) \{\n"
    r"        self\.init\(named: name, in: \.module, compatibleWith: nil\)!\n"
    r"    \}\n"
    r"\}\n?",
    re.MULTILINE,
)

IMPORT_LINE = re.compile(
    r"^import (?:Runestone|RunestoneThemeCommon|RunestoneLanguageSupport|"
    r"TreeSitter(?:[A-Za-z0-9]+)?)\s*$",
    re.MULTILINE,
)


def die(message: str) -> None:
    raise SystemExit(f"[!] {message}")


def copytree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def discover_languages(language_root: Path) -> list[str]:
    names: list[str] = []
    for path in sorted(language_root.iterdir()):
        if not path.is_dir():
            continue
        name = path.name
        if name in SKIP_LANGUAGE_DIRS:
            continue
        if name.endswith("Queries") or name.endswith("Runestone"):
            continue
        if not name.startswith("TreeSitter"):
            continue
        if (path / "include" / "public.h").is_file():
            names.append(name)
    if not names:
        die(f"no Tree-sitter languages found in {language_root}")
    return names


def language_key(module_name: str) -> str:
    return module_name[len("TreeSitter") :]


def rewrite_runestone_swift(text: str, relative: Path | None = None) -> str:
    text = re.sub(r"^import TreeSitter\s*\n", "", text, flags=re.MULTILINE)
    text = text.replace("enum HighlightName: String", "enum DefaultThemeHighlightName: String")
    text = text.replace("HighlightName(", "DefaultThemeHighlightName(")
    text = text.replace("if let highlightName = HighlightName", "if let highlightName = DefaultThemeHighlightName")
    name = relative.name if relative else ""
    if name == "L10n.swift":
        # Static framework: Bundle(for:) resolves to the linking binary, not to
        # the embedded Runestone.framework that carries the .lproj folders.
        text = text.replace("return Bundle(for: BundleToken.self)", "return Bundle.module")
    elif name == "TextView.swift":
        # @available(iOS 26.0, *) on scrollPocketView is remapped to visionOS 26 but the call-site check is not.
        text = text.replace("if #available(iOS 26, *), let scrollPocketView {", "if #available(iOS 26, visionOS 26, *), let scrollPocketView {")
    elif name == "TreeSitterParser.swift":
        text = text.replace("private var pointer: OpaquePointer", "private var pointer: UnsafeMutablePointer<TSParser>")
        text = text.replace("self.pointer = ts_parser_new()", "self.pointer = ts_parser_new()!")
    elif name == "TreeSitterQuery.swift":
        text = text.replace("let pointer: OpaquePointer", "let pointer: UnsafeMutablePointer<TSQuery>")
    elif name == "TreeSitterTree.swift":
        text = text.replace("let pointer: OpaquePointer", "let pointer: UnsafeMutablePointer<TSTree>")
        text = text.replace("init(_ tree: OpaquePointer)", "init(_ tree: UnsafeMutablePointer<TSTree>)")
    elif name == "TreeSitterQueryCursor.swift":
        text = text.replace("private let pointer: OpaquePointer", "private let pointer: UnsafeMutablePointer<TSQueryCursor>")
        text = text.replace("self.pointer = ts_query_cursor_new()", "self.pointer = ts_query_cursor_new()!")
    return text


def rewrite_theme_swift(text: str) -> str:
    text = IMPORT_LINE.sub("", text)
    text = NAMED_IN_MODULE_BLOCK.sub("\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def rewrite_query_swift(text: str, enum_name: str, subdirectory: str) -> str:
    variables = re.findall(
        r"public static var (\w+): URL \{\s+url\(named: \"([^\"]+)\"\)",
        text,
    )
    if not variables:
        die(f"failed to parse query declarations for {enum_name}")
    lines = [
        "import Foundation",
        "",
        f"public enum {enum_name} {{",
    ]
    for property_name, resource_name in variables:
        lines.extend(
            [
                f"    public static var {property_name}: URL {{",
                f"        url(named: \"{resource_name}\")",
                "    }",
                "",
            ]
        )
    lines.extend(
        [
            "    private static func url(named filename: String) -> URL {",
            "        Bundle.module.url(",
            "            forResource: filename,",
            "            withExtension: \"scm\",",
            f"            subdirectory: \"{subdirectory}\"",
            "        )!",
            "    }",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def rewrite_language_helper_swift(text: str) -> str:
    text = IMPORT_LINE.sub("", text)
    if "import Foundation" not in text:
        text = "import Foundation\n" + text
    text = re.sub(
        r"TreeSitter([A-Za-z0-9]+)Queries\.Query\.",
        r"TreeSitter\1Queries.",
        text,
    )
    text = text.replace("combinedQuery(fromFilesAt:", "RunestoneCombinedQuery.fromFiles(at:")
    text = COMBINED_QUERY_BLOCK.sub("\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def copy_tree_sitter_core(src: Path, dest_core: Path, dest_public: Path) -> None:
    copytree(src / "src", dest_core / "src")
    copytree(src / "include" / "tree_sitter", dest_core / "include" / "tree_sitter")
    copytree(src / "include" / "tree_sitter", dest_public / "tree_sitter")


def copy_language(
    src_root: Path,
    name: str,
    dest_languages: Path,
    dest_queries: Path,
    dest_swift: Path,
    public_headers: list[str],
) -> None:
    src = src_root / name
    dest = dest_languages / name
    copytree(src, dest)

    public_h = dest / "include" / "public.h"
    prototypes = re.findall(
        r"const TSLanguage\s*\*\s*tree_sitter_\w+\s*\(\s*void\s*\)\s*;",
        public_h.read_text(encoding="utf-8"),
    )
    if not prototypes:
        die(f"no language prototype in {public_h}")
    public_headers.extend(prototypes)

    query_dir = src_root / f"{name}Queries"
    if query_dir.is_dir():
        query_dest = dest_queries / name
        query_dest.mkdir(parents=True, exist_ok=True)
        for scm in sorted(query_dir.glob("*.scm")):
            shutil.copy2(scm, query_dest / scm.name)
        query_swift = query_dir / "Query.swift"
        if query_swift.is_file():
            write_text(
                dest_swift / "Queries" / f"{name}Queries.swift",
                rewrite_query_swift(
                    query_swift.read_text(encoding="utf-8"),
                    f"{name}Queries",
                    f"Queries/{name}",
                ),
            )

    helper_dir = src_root / f"{name}Runestone"
    if helper_dir.is_dir():
        for swift in sorted(helper_dir.glob("*.swift")):
            write_text(
                dest_swift / "Languages" / f"{name}_{swift.name}",
                rewrite_language_helper_swift(swift.read_text(encoding="utf-8")),
            )


def copy_runestone_sources(src: Path, dest: Path) -> None:
    for path in src.rglob("*"):
        relative = path.relative_to(src)
        parts = relative.parts
        if not parts:
            continue
        if parts[0] == "Documentation.docc":
            continue
        dest_path = dest / relative
        if path.is_dir():
            dest_path.mkdir(parents=True, exist_ok=True)
            continue
        if path.suffix == ".swift":
            write_text(dest_path, rewrite_runestone_swift(path.read_text(encoding="utf-8"), relative))
        else:
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest_path)


def copy_themes(src_root: Path, dest_swift: Path, dest_assets: Path) -> None:
    theme_map = {
        "RunestoneTomorrowTheme": "Tomorrow",
        "RunestoneOneDarkTheme": "OneDark",
        "RunestonePlainTextTheme": "PlainText",
        "RunestoneThemeCommon": "ThemeCommon",
    }
    for module_name, dest_name in theme_map.items():
        module_dir = src_root / module_name
        if not module_dir.is_dir():
            die(f"missing theme module {module_name}")
        for swift in sorted(module_dir.glob("*.swift")):
            if swift.name == "RunestoneThemeSupport.swift":
                continue
            write_text(
                dest_swift / "Themes" / f"{dest_name}_{swift.name}",
                rewrite_theme_swift(swift.read_text(encoding="utf-8")),
            )
        assets = module_dir / "Colors.xcassets"
        if assets.is_dir():
            copytree(assets, dest_assets / f"{dest_name}.xcassets")


def copy_framework_support(src: Path, dest: Path) -> None:
    for swift in sorted(src.glob("*.swift")):
        shutil.copy2(swift, dest / "Support" / swift.name)
    write_text(
        dest / "Support" / "RunestoneDummy.m",
        '#import "Runestone.h"\n',
    )


def make_umbrella(public_dir: Path, language_headers: list[str]) -> None:
    languages_h = "\n".join(
        [
            "#ifndef RUNESTONE_LANGUAGES_H_",
            "#define RUNESTONE_LANGUAGES_H_",
            "",
            '#include "api.h"',
            "",
            "#ifdef __cplusplus",
            'extern "C" {',
            "#endif",
            "",
        ]
        + language_headers
        + [
            "",
            "#ifdef __cplusplus",
            "}",
            "#endif",
            "",
            "#endif /* RUNESTONE_LANGUAGES_H_ */",
            "",
        ]
    )
    write_text(public_dir / "languages.h", languages_h)
    write_text(
        public_dir / "Runestone.h",
        "\n".join(
            [
                "#ifndef RUNESTONE_H",
                "#define RUNESTONE_H",
                "",
                "#include <stdint.h>",
                "",
                "struct TSLanguage { uint8_t _runestone_opaque; };",
                "struct TSParser { uint8_t _runestone_opaque; };",
                "struct TSTree { uint8_t _runestone_opaque; };",
                "struct TSQuery { uint8_t _runestone_opaque; };",
                "struct TSQueryCursor { uint8_t _runestone_opaque; };",
                "struct TSLookaheadIterator { uint8_t _runestone_opaque; };",
                "",
                '#include "api.h"',
                '#include "languages.h"',
                "",
                "#endif /* RUNESTONE_H */",
                "",
            ]
        ),
    )
    shutil.copy2(public_dir / "tree_sitter" / "api.h", public_dir / "api.h")
    clang_dir = public_dir.parent / "clang"
    (clang_dir / "tree_sitter").mkdir(parents=True, exist_ok=True)
    shutil.copy2(public_dir / "tree_sitter" / "api.h", clang_dir / "tree_sitter" / "api.h")
    if (public_dir / "tree_sitter" / "parser.h").is_file():
        shutil.copy2(public_dir / "tree_sitter" / "parser.h", clang_dir / "tree_sitter" / "parser.h")
    shutil.copy2(public_dir / "languages.h", clang_dir / "languages.h")
    write_text(
        clang_dir / "TreeSitter.h",
        "\n".join(
            [
                "#ifndef RUNESTONE_TREESITTER_H",
                "#define RUNESTONE_TREESITTER_H",
                "",
                "#include <stdint.h>",
                "",
                "/* Xcode 27's Swift importer skips incomplete C structs. Complete",
                "   them before api.h so function signatures import as named pointers. */",
                "struct TSLanguage { uint8_t _runestone_opaque; };",
                "struct TSParser { uint8_t _runestone_opaque; };",
                "struct TSTree { uint8_t _runestone_opaque; };",
                "struct TSQuery { uint8_t _runestone_opaque; };",
                "struct TSQueryCursor { uint8_t _runestone_opaque; };",
                "struct TSLookaheadIterator { uint8_t _runestone_opaque; };",
                "",
                '#include "tree_sitter/api.h"',
                '#include "languages.h"',
                "",
                "#endif",
                "",
            ]
        ),
    )
    write_text(
        clang_dir / "module.modulemap",
        "\n".join(
            [
                "module TreeSitter {",
                '    header "TreeSitter.h"',
                "    export *",
                "}",
                "",
            ]
        ),
    )


def header_search_paths(language_names: list[str]) -> list[str]:
    paths = [
        "$(SRCROOT)/src/public",
        "$(SRCROOT)/src/TreeSitterCore/include",
        "$(SRCROOT)/src/TreeSitterCore/src",
    ]
    for name in language_names:
        paths.append(f"$(SRCROOT)/src/Languages/{name}/src")
        paths.append(f"$(SRCROOT)/src/Languages/{name}/include")
    return paths


def xid(*parts: str) -> str:
    digest = hashlib.md5("|".join(parts).encode()).hexdigest()[:24].upper()
    return digest


def pbx_quote(value: str) -> str:
    if value.isidentifier() and value not in {"and", "or"}:
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def pbx_list(values: list[str], indent: str) -> str:
    if not values:
        return f"(\n{indent})"
    inner = "\n".join(f"{indent}\t{pbx_quote(value)}," for value in values)
    return f"(\n{inner}\n{indent})"


def relative_posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def collect_core_exceptions(core_dir: Path) -> list[str]:
    exceptions: list[str] = []
    for path in sorted(core_dir.rglob("*")):
        if not path.is_file():
            continue
        relative = relative_posix(path, core_dir)
        if path.suffix == ".c" and path.name != "lib.c":
            exceptions.append(relative)
    return exceptions


def collect_language_exceptions(languages_dir: Path) -> list[str]:
    exceptions: list[str] = []
    skip_suffixes = {".h", ".md"}
    skip_names = {"schema.generated.cc", "chars.c"}
    for path in sorted(languages_dir.rglob("*")):
        if not path.is_file():
            continue
        relative = relative_posix(path, languages_dir)
        if path.suffix in skip_suffixes:
            exceptions.append(relative)
            continue
        if path.name in skip_names:
            exceptions.append(relative)
            continue
        if relative.endswith("tree_sitter_comment/parser.c"):
            exceptions.append(relative)
            continue
        if path.suffix not in {".c", ".cc", ".m", ".mm"}:
            exceptions.append(relative)
    return exceptions


def collect_runestone_exceptions(swift_dir: Path) -> list[str]:
    exceptions: list[str] = []
    for path in sorted(swift_dir.rglob("*")):
        if not path.is_file():
            continue
        relative = relative_posix(path, swift_dir)
        if relative.startswith("Resources/Queries/"):
            exceptions.append(relative)
            continue
        if path.suffix in {".h", ".md"}:
            exceptions.append(relative)
    return exceptions


def collect_public_headers(public_dir: Path) -> tuple[list[str], list[str]]:
    public_headers: list[str] = []
    membership_exceptions: list[str] = []
    for path in sorted(public_dir.rglob("*")):
        if not path.is_file():
            continue
        relative = relative_posix(path, public_dir)
        if relative.startswith("tree_sitter/"):
            membership_exceptions.append(relative)
            continue
        if path.suffix == ".h":
            public_headers.append(relative)
        else:
            membership_exceptions.append(relative)
    return public_headers, membership_exceptions


def write_xcode_scheme(path: Path, target_id: str) -> None:
    write_text(
        path,
        """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2630"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "TARGET_ID"
               BuildableName = "Runestone.framework"
               BlueprintName = "Runestone"
               ReferencedContainer = "container:Runestone.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""".replace("TARGET_ID", target_id),
    )


def write_xcode_project(root: Path, language_names: list[str]) -> None:
    src_root = root / "build" / "src"
    core_dir = src_root / "TreeSitterCore"
    languages_dir = src_root / "Languages"
    swift_dir = src_root / "Runestone"
    public_dir = src_root / "public"

    project_id = xid("project")
    target_id = xid("target")
    product_id = xid("product")
    main_group_id = xid("main-group")
    products_group_id = xid("products-group")
    sources_phase_id = xid("sources-phase")
    frameworks_phase_id = xid("frameworks-phase")
    resources_phase_id = xid("resources-phase")
    headers_phase_id = xid("headers-phase")
    project_config_list_id = xid("project-config-list")
    target_config_list_id = xid("target-config-list")
    project_debug_id = xid("project-debug")
    project_release_id = xid("project-release")
    target_debug_id = xid("target-debug")
    target_release_id = xid("target-release")

    core_group_id = xid("sync-core")
    languages_group_id = xid("sync-languages")
    runestone_group_id = xid("sync-runestone")
    public_group_id = xid("sync-public")
    core_exc_id = xid("exc-core")
    languages_exc_id = xid("exc-languages")
    runestone_exc_id = xid("exc-runestone")
    public_exc_id = xid("exc-public")
    queries_ref_id = xid("queries-ref")
    queries_build_id = xid("queries-build")

    core_exceptions = collect_core_exceptions(core_dir)
    language_exceptions = collect_language_exceptions(languages_dir)
    runestone_exceptions = collect_runestone_exceptions(swift_dir)
    public_headers, public_membership = collect_public_headers(public_dir)
    header_paths = header_search_paths(language_names)

    def settings_block(extra: dict[str, str], indent: str = "\t\t\t\t") -> str:
        merged = {
            "ALWAYS_SEARCH_USER_PATHS": "NO",
            "APPLICATION_EXTENSION_API_ONLY": "NO",
            "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",
            "CLANG_CXX_LANGUAGE_STANDARD": '"c++14"',
            "CLANG_CXX_LIBRARY": '"libc++"',
            "CLANG_ENABLE_MODULES": "YES",
            "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "NO",
            "CODE_SIGN_STYLE": "Automatic",
            "COMPILER_INDEX_STORE_ENABLE": "NO",
            "COPY_PHASE_STRIP": "NO",
            "CURRENT_PROJECT_VERSION": "1",
            "DEFINES_MODULE": "YES",
            "DYLIB_COMPATIBILITY_VERSION": "1",
            "DYLIB_CURRENT_VERSION": "1",
            "DYLIB_INSTALL_NAME_BASE": '"@rpath"',
            "ENABLE_MODULE_VERIFIER": "NO",
            "GCC_WARN_INHIBIT_ALL_WARNINGS": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_CFBundleDisplayName": "Runestone",
            "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
            "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"',
            "MACOSX_DEPLOYMENT_TARGET": "11.0",
            "MACH_O_TYPE": "staticlib",
            "MARKETING_VERSION": "1.0.0",
            "OTHER_CFLAGS": '"-w"',
            "OTHER_CPLUSPLUSFLAGS": '"-w -std=c++14"',
            "OTHER_LDFLAGS": '"-lc++"',
            "OTHER_SWIFT_FLAGS": '"$(inherited) -import-underlying-module"',
            "PRODUCT_BUNDLE_IDENTIFIER": '"app.runestone.Runestone"',
            "PRODUCT_MODULE_NAME": "Runestone",
            "PRODUCT_NAME": "Runestone",
            "SDKROOT": "iphoneos",
            "SKIP_INSTALL": "NO",
            "STRIP_INSTALLED_PRODUCT": "NO",
            "SUPPORTED_PLATFORMS": '"iphoneos iphonesimulator xros xrsimulator"',
            "SUPPORTS_MACCATALYST": "YES",
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
            "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
            "SWIFT_ENABLE_EXPLICIT_MODULES": "NO",
            "SWIFT_INCLUDE_PATHS": '"$(SRCROOT)/src/clang"',
            "SWIFT_INSTALL_OBJC_HEADER": "YES",
            "SWIFT_SERIALIZE_DEBUGGING_OPTIONS": "NO",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": '"1,2,7"',
            "XROS_DEPLOYMENT_TARGET": "1.0",
        }
        merged.update(extra)
        lines = [f'{indent}HEADER_SEARCH_PATHS = (']
        for path in header_paths:
            lines.append(f'{indent}\t"{path}",')
        lines.append(f"{indent});")
        for key, value in merged.items():
            lines.append(f"{indent}{key} = {value};")
        return "\n".join(lines)

    debug_settings = settings_block(
        {
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_TESTABILITY": "YES",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
            "ONLY_ACTIVE_ARCH": "YES",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
            "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
        }
    )
    release_settings = settings_block(
        {
            "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
            "MTL_ENABLE_DEBUG_INFO": "NO",
            "SWIFT_COMPILATION_MODE": "wholemodule",
            "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
            "VALIDATE_PRODUCT": "YES",
        }
    )

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXBuildFile section */
		{queries_build_id} /* Queries in Resources */ = {{isa = PBXBuildFile; fileRef = {queries_ref_id} /* Queries */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{product_id} /* Runestone.framework */ = {{isa = PBXFileReference; explicitFileType = wrapper.framework; includeInIndex = 0; path = Runestone.framework; sourceTree = BUILT_PRODUCTS_DIR; }};
		{queries_ref_id} /* Queries */ = {{isa = PBXFileReference; lastKnownFileType = folder; name = Queries; path = src/Runestone/Resources/Queries; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		{core_exc_id} /* Exceptions for TreeSitterCore */ = {{
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = {pbx_list(core_exceptions, chr(9)*3).lstrip()};
			target = {target_id} /* Runestone */;
		}};
		{languages_exc_id} /* Exceptions for Languages */ = {{
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = {pbx_list(language_exceptions, chr(9)*3).lstrip()};
			target = {target_id} /* Runestone */;
		}};
		{runestone_exc_id} /* Exceptions for Runestone */ = {{
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = {pbx_list(runestone_exceptions, chr(9)*3).lstrip()};
			target = {target_id} /* Runestone */;
		}};
		{public_exc_id} /* Exceptions for public headers */ = {{
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = {pbx_list(public_membership, chr(9)*3).lstrip()};
			publicHeaders = {pbx_list(public_headers, chr(9)*3).lstrip()};
			target = {target_id} /* Runestone */;
		}};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{core_group_id} /* TreeSitterCore */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				{core_exc_id} /* Exceptions for TreeSitterCore */,
			);
			path = "src/TreeSitterCore";
			sourceTree = "<group>";
		}};
		{languages_group_id} /* Languages */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				{languages_exc_id} /* Exceptions for Languages */,
			);
			path = "src/Languages";
			sourceTree = "<group>";
		}};
		{runestone_group_id} /* Runestone */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				{runestone_exc_id} /* Exceptions for Runestone */,
			);
			path = "src/Runestone";
			sourceTree = "<group>";
		}};
		{public_group_id} /* public */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				{public_exc_id} /* Exceptions for public headers */,
			);
			path = "src/public";
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
				{core_group_id} /* TreeSitterCore */,
				{languages_group_id} /* Languages */,
				{runestone_group_id} /* Runestone */,
				{public_group_id} /* public */,
				{queries_ref_id} /* Queries */,
				{products_group_id} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_id} /* Runestone.framework */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXHeadersBuildPhase section */
		{headers_phase_id} /* Headers */ = {{
			isa = PBXHeadersBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXHeadersBuildPhase section */

/* Begin PBXNativeTarget section */
		{target_id} /* Runestone */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_config_list_id} /* Build configuration list for PBXNativeTarget "Runestone" */;
			buildPhases = (
				{headers_phase_id} /* Headers */,
				{sources_phase_id} /* Sources */,
				{frameworks_phase_id} /* Frameworks */,
				{resources_phase_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{core_group_id} /* TreeSitterCore */,
				{languages_group_id} /* Languages */,
				{runestone_group_id} /* Runestone */,
				{public_group_id} /* public */,
			);
			name = Runestone;
			productName = Runestone;
			productReference = {product_id} /* Runestone.framework */;
			productType = "com.apple.product-type.framework";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 2630;
			}};
			buildConfigurationList = {project_config_list_id} /* Build configuration list for PBXProject "Runestone" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_id};
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_id} /* Runestone */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{queries_build_id} /* Queries in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{project_debug_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{debug_settings}
			}};
			name = Debug;
		}};
		{project_release_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{release_settings}
			}};
			name = Release;
		}};
		{target_debug_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{debug_settings}
			}};
			name = Debug;
		}};
		{target_release_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{release_settings}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{project_config_list_id} /* Build configuration list for PBXProject "Runestone" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{project_debug_id} /* Debug */,
				{project_release_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_config_list_id} /* Build configuration list for PBXNativeTarget "Runestone" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{target_debug_id} /* Debug */,
				{target_release_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project_id} /* Project object */;
}}
"""

    project_dir = root / "build" / "Runestone.xcodeproj"
    write_text(project_dir / "project.pbxproj", pbx)
    write_text(
        project_dir / "project.xcworkspace" / "contents.xcworkspacedata",
        """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
    )
    write_xcode_scheme(project_dir / "xcshareddata" / "xcschemes" / "Runestone.xcscheme", target_id)
    print(f"[*] wrote {project_dir}")



def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--references", required=True, type=Path)
    args = parser.parse_args()

    root: Path = args.root.resolve()
    references: Path = args.references.resolve()
    runestone_src = references / "Runestone" / "Sources" / "Runestone"
    editor_src = root / "Vendor" / "RunestoneEditor"
    if not runestone_src.is_dir():
        die(f"Runestone sources missing: {runestone_src}")
    if not editor_src.is_dir():
        die(f"vendored RunestoneEditor missing: {editor_src}")

    src_root = root / "build" / "src"
    if src_root.exists():
        shutil.rmtree(src_root)

    public_dir = src_root / "public"
    core_dir = src_root / "TreeSitterCore"
    languages_dir = src_root / "Languages"
    swift_dir = src_root / "Runestone"
    queries_dir = swift_dir / "Resources" / "Queries"
    assets_dir = swift_dir / "Resources" / "Themes"

    for path in (public_dir, core_dir, languages_dir, swift_dir / "Support", swift_dir / "Themes", swift_dir / "Languages", swift_dir / "Queries"):
        path.mkdir(parents=True, exist_ok=True)

    copy_tree_sitter_core(editor_src / "TreeSitter" / "Sources" / "TreeSitter", core_dir, public_dir)

    language_root = editor_src / "RunestoneLanguageSupport" / "Sources"
    language_names = discover_languages(language_root)
    public_headers: list[str] = []
    for name in language_names:
        print(f"[*] language {name}")
        copy_language(language_root, name, languages_dir, queries_dir, swift_dir, public_headers)

    copy_runestone_sources(runestone_src, swift_dir)
    copy_themes(editor_src / "RunestoneThemeSupport" / "Sources", swift_dir, assets_dir)
    copy_framework_support(root / "Sources" / "FrameworkSupport", swift_dir)
    make_umbrella(public_dir, public_headers)
    write_xcode_project(root, language_names)

    print(f"[*] assembled {len(language_names)} languages into {src_root}")


if __name__ == "__main__":
    main()
