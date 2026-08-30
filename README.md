# Runestone

Swift package wrapping a pre-built [Runestone](https://github.com/simonbs/Runestone) XCFramework for Apple platforms.

Tree-sitter, language grammars, and themes are compiled into the binary so consuming apps do not rebuild 200+ MB of `parser.c` on every clean build.

This replaces [Runestone](https://github.com/Lakr233/Runestone) and [RunestoneEditor](https://github.com/Lakr233/RunestoneEditor).

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

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/Lakr233/Runestone.xcframework.git", from: "0.2.0"),
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

## Local build

Requires Xcode and Python 3.

```bash
./Script/build.sh
```

Useful flags:

```bash
./Script/build.sh --platforms iossimulator
./Script/build.sh --skip-fetch          # reuse ./References
./Script/build.sh --skip-tests
```

The script:

1. Fetches pinned upstreams into `References/` (`Upstream.versions`)
2. Flattens Runestone + Tree-sitter + languages + themes into one module
3. Writes `build/Runestone.xcodeproj` and archives iOS, iOS Simulator, Mac Catalyst, visionOS, and visionOS Simulator
4. Emits `BinaryTarget/Runestone.xcframework` and `build/Runestone.xcframework.zip`

## Compile test

```bash
./Script/test.sh
```

Builds every product for each platform slice, the example app for iOS, iOS Simulator, and Mac Catalyst, then runs `Tests/RunestoneTests` on Mac Catalyst. It links whatever `Package.swift` points at: the released binary on a fresh checkout, `BinaryTarget/` after `./Script/build.sh`.

## Upstream sources

Pinned in `Upstream.versions`:

- [simonbs/Runestone](https://github.com/simonbs/Runestone) `0.5.2` — the editor. The Tomorrow, One Dark, and Plain Text themes are Simon Støvring's as well, from its `Example/Themes`.
- [simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) — Simon Støvring's Tree-sitter grammars, queries, and Runestone bindings, on top of the [tree-sitter](https://github.com/tree-sitter/tree-sitter) runtime.
- [Lakr233/RunestoneEditor](https://github.com/Lakr233/RunestoneEditor) — repackages the above as nested packages and adds the `RunestoneEditorView` convenience API.

## CI and release

All workflows run on GitHub-hosted `macos-26`:

- **PR Build & Test** — runs `./Script/test.sh` against the released binary
- **Build XCFramework** — `workflow_dispatch`; builds every slice, runs the compile test, uploads the zip artifact (optional `storage.<version>` release)
- **Release Package** — `workflow_dispatch` with a semver; builds every slice, runs the compile test, writes the `Package.swift` checksum, tags `storage.<version>` (binary) and `<version>` (Swift package)
- **UI Tests** — builds the XCFramework, then runs `Example/MobileRunestoneApp`

Local equivalent of a package release:

```bash
./Script/build.sh
./Script/test.sh
./Script/build-manifest.sh build/Runestone.xcframework.zip \
  "https://github.com/Lakr233/Runestone.xcframework/releases/download/storage.<version>/Runestone.xcframework.zip"
```

## License

MIT. Bundled upstream components keep their original licenses (Runestone, Tree-sitter, and the individual grammars).
