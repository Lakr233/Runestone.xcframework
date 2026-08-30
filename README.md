# Runestone

Swift package wrapping a pre-built [Runestone](https://github.com/simonbs/Runestone) XCFramework for Apple platforms.

Tree-sitter, language grammars, and themes are compiled into the binary so consuming apps do not rebuild 200+ MB of `parser.c` on every clean build.

This replaces [Runestone](https://github.com/Lakr233/Runestone) and [RunestoneEditor](https://github.com/Lakr233/RunestoneEditor).

## Platforms

- iOS 15+
- Mac Catalyst 15+

## Products

| Library | Description |
| --- | --- |
| `Runestone` | Prebuilt XCFramework (editor, languages, themes, Tree-sitter) |
| `RunestoneEditor` | `@_exported import Runestone` — drop-in for the old nested package |
| `RunestoneLanguageSupport` | Compatibility shim |
| `RunestoneThemeSupport` | Compatibility shim |

`import RunestoneEditor` is enough. The extra products exist so existing `import RunestoneLanguageSupport` / `import RunestoneThemeSupport` sites keep compiling.

## Installation

Until the first GitHub release, build locally and use the path-based binary target already in `Package.swift`:

```bash
./Script/build.sh
```

After a release:

```swift
dependencies: [
    .package(url: "https://github.com/Lakr233/Runestone.xcframework.git", from: "1.0.0"),
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
3. Writes `Runestone.xcodeproj` and archives iOS, iOS Simulator, and Mac Catalyst
4. Emits `BinaryTarget/Runestone.xcframework` and `build/Runestone.xcframework.zip`

Verify the example app against the local binary:

```bash
./Script/test.sh
```

Pinned sources:

- [simonbs/Runestone](https://github.com/simonbs/Runestone) `0.5.2`
- [Lakr233/RunestoneEditor](https://github.com/Lakr233/RunestoneEditor) for Tree-sitter, language grammars, and themes

## Release

CI runs on the in-house mini-control fleet:

```text
runs-on: [self-hosted, macos, arm64, mini-control]
```

GitHub Actions:

- **Build XCFramework** — `workflow_dispatch`, produces the zip artifact (optional `storage.<version>` release)
- **Release Package** — `workflow_dispatch` with a semver; writes `Package.swift` checksum, tags `storage.<version>` (binary) and `<version>` (Swift package)
- **UI Tests** — builds the XCFramework, then runs `Example/MobileRunestoneApp`

Local equivalent of a package release:

```bash
./Script/build.sh --download-url \
  "https://github.com/Lakr233/Runestone.xcframework/releases/download/storage.1.0.0/Runestone.xcframework.zip"
```

## License

MIT. Bundled upstream components keep their original licenses (Runestone, Tree-sitter, and the individual grammars).
