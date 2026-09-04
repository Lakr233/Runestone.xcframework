# Runestone

Swift package wrapping a pre-built [Runestone](https://github.com/simonbs/Runestone) XCFramework for Apple platforms.

Tree-sitter, language grammars, and themes are compiled into the binary so consuming apps do not rebuild 200+ MB of `parser.c` on every clean build.

This replaces the former `Lakr233/Runestone` and `Lakr233/RunestoneEditor` packages. What the binary needs from RunestoneEditor (Tree-sitter runtime, grammars, themes) is vendored in `Vendor/RunestoneEditor`; the editor itself is fetched from `simonbs/Runestone` at build time.

## Platforms

- iOS 15+
- Mac Catalyst 15+
- visionOS 1+

## Products

| Library | Description |
| --- | --- |
| `Runestone` | Prebuilt XCFramework (editor, languages, themes, Tree-sitter) |
| `RunestoneEditor` | `@_exported import Runestone` — drop-in for the old nested package |
| `RunestoneLanguageSupport` | Compatibility shim |
| `RunestoneThemeSupport` | Compatibility shim |

`import RunestoneEditor` is enough. The extra products exist so existing `import RunestoneLanguageSupport` / `import RunestoneThemeSupport` sites keep compiling.

## Linking

The XCFramework is a **static** framework, so Runestone links into whatever binary imports it and the linker can strip the grammars you never load. Xcode still copies `Runestone.framework` into `YourApp.app/Frameworks`, but only for the resources (queries, theme colors, localizations, `PrivacyInfo.xcprivacy`) — the binary in there is an empty stub, not the 100 MB archive.

The static binary needs the C++ standard library. The three shim products already link it; if you depend on the raw `Runestone` product, or wire the XCFramework up by hand, add `.linkedLibrary("c++")` (or `-lc++`) yourself.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Lakr233/Runestone.xcframework.git", from: "0.3.0"),
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "RunestoneEditor", package: "Runestone"),
    ]
)
```

## Usage

Start from `Example/MobileRunestoneApp/` — iOS / Mac Catalyst UIKit demo with theme and language menus.

```swift
import RunestoneEditor

let textView = RunestoneEditorView.new()
textView.apply(theme: TomorrowTheme(size: 14))
if let language = TreeSitterLanguage.language(withIdentifier: "swift") {
    textView.apply(language: language)
}
```

## Upstream Sources

- [simonbs/Runestone](https://github.com/simonbs/Runestone) `0.5.2` — the editor, pinned by SHA in `Upstream.versions` and fetched into `References/` at build time. The Tomorrow, One Dark, and Plain Text themes are Simon Støvring's as well, from its `Example/Themes`.
- `Vendor/RunestoneEditor/` — checked in, formerly the `External/` tree of the (now deleted) `Lakr233/RunestoneEditor` package:
  - [tree-sitter](https://github.com/tree-sitter/tree-sitter) runtime
  - [simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) — Simon Støvring's grammars, queries, and Runestone bindings
  - the themes above
- `Sources/FrameworkSupport/` — `RunestoneEditorView` convenience API and module glue compiled into the framework.

See `Vendor/RunestoneEditor/README.md` for provenance and licenses.

## Maintaining this repository

Building the XCFramework, the release workflows, and the constraints behind the current linking setup live in [AGENTS.md](AGENTS.md).

## License

MIT. Bundled upstream components keep their original licenses (Runestone, Tree-sitter, and the individual grammars).
