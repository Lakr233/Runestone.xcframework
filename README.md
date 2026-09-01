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

1. Fetches the pinned `simonbs/Runestone` into `References/` (`Upstream.versions`)
2. Flattens it with `Vendor/RunestoneEditor` (Tree-sitter + languages + themes) and `Sources/FrameworkSupport` into one module
3. Writes `build/Runestone.xcodeproj` and archives iOS, iOS Simulator, Mac Catalyst, visionOS, and visionOS Simulator
4. Emits `BinaryTarget/Runestone.xcframework` and `build/Runestone.xcframework.zip`

## Compile test

```bash
./Script/test.sh
```

Builds every product for each platform slice, the example app for iOS, iOS Simulator, and Mac Catalyst, then runs `Tests/RunestoneTests` on Mac Catalyst. It links whatever `Package.swift` points at: the released binary on a fresh checkout, `BinaryTarget/` after `./Script/build.sh`.

## Upstream sources

- [simonbs/Runestone](https://github.com/simonbs/Runestone) `0.5.2` — the editor, pinned by SHA in `Upstream.versions` and fetched into `References/` at build time. The Tomorrow, One Dark, and Plain Text themes are Simon Støvring's as well, from its `Example/Themes`.
- `Vendor/RunestoneEditor/` — checked in, formerly the `External/` tree of the (now deleted) `Lakr233/RunestoneEditor` package:
  - [tree-sitter](https://github.com/tree-sitter/tree-sitter) runtime
  - [simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) — Simon Støvring's grammars, queries, and Runestone bindings
  - the themes above
- `Sources/FrameworkSupport/` — `RunestoneEditorView` convenience API and module glue compiled into the framework.

See `Vendor/RunestoneEditor/README.md` for provenance and licenses.

## CI and release

All workflows run on GitHub-hosted `macos-26`. Building the Tree-sitter grammars for five slices is slow, so a release is split in two: the binary is built once and published under its own tag, and package versions only point at it.

Tags:

- `upstream.<major>.<minor>.<patch>-<rev>` — binary release (`Runestone.xcframework.zip`). `<major>.<minor>.<patch>` is `RUNESTONE_VERSION` from `Upstream.versions`; `<rev>` increments on every build of the same upstream (vendored sources or build changed).
- `<major>.<minor>.<patch>` — Swift package release; `Package.swift` points at one `upstream.*` asset.

Workflows:

- **Build XCFramework** — weekly (Monday 03:00 UTC) and `workflow_dispatch`. Fetches upstream, archives every slice, publishes `upstream.<version>-<rev>` (next free rev), then dispatches **Release Package** with `package_version` (input, or latest package tag + patch). The weekly run checks the newest `simonbs/Runestone` tag and only builds when it has no `upstream.*` release yet, re-pinning `Upstream.versions` and committing the bump. Manual runs build the pinned version; set `upstream_version` (`latest` or a tag) to re-pin, untick `release_package` to only publish the binary.
- **Release Package** — `workflow_dispatch` with `package_version` and `upstream_tag`. Downloads that binary, writes the `Package.swift` URL + checksum, runs `./Script/test.sh` against it (SwiftPM resolves the published zip), commits the manifest, and tags the package release. Never rebuilds — reuse an existing `upstream.*` tag to ship shim-only changes in minutes.
- **PR Build & Test** — runs `./Script/test.sh` against the released binary
- **UI Tests** — builds the XCFramework, then runs `Example/MobileRunestoneApp`

Local equivalent:

```bash
./Script/resolve-upstream.sh latest --write   # optional: re-pin simonbs/Runestone
./Script/next-tag.sh upstream                 # e.g. upstream.0.5.2-2
./Script/build.sh
gh release create upstream.0.5.2-2 --latest=false build/Runestone.xcframework.zip
./Script/build-manifest.sh build/Runestone.xcframework.zip \
  "https://github.com/Lakr233/Runestone.xcframework/releases/download/upstream.0.5.2-2/Runestone.xcframework.zip"
./Script/test.sh
git commit -am "release: 0.2.2 (upstream.0.5.2-2)" && git push
gh release create 0.2.2 --latest
```

## License

MIT. Bundled upstream components keep their original licenses (Runestone, Tree-sitter, and the individual grammars).
