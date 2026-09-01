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

## Local Build

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

## Compile Test

```bash
./Script/test.sh
```

Builds every product for each platform slice, the example app for iOS, iOS Simulator, and Mac Catalyst, then runs `Tests/RunestoneTests` on Mac Catalyst. It links whatever `Package.swift` points at: the released binary on a fresh checkout, `BinaryTarget/` after `./Script/build.sh`.

## Upstream Sources

- [simonbs/Runestone](https://github.com/simonbs/Runestone) `0.5.2` — the editor, pinned by SHA in `Upstream.versions` and fetched into `References/` at build time. The Tomorrow, One Dark, and Plain Text themes are Simon Støvring's as well, from its `Example/Themes`.
- `Vendor/RunestoneEditor/` — checked in, formerly the `External/` tree of the (now deleted) `Lakr233/RunestoneEditor` package:
  - [tree-sitter](https://github.com/tree-sitter/tree-sitter) runtime
  - [simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) — Simon Støvring's grammars, queries, and Runestone bindings
  - the themes above
- `Sources/FrameworkSupport/` — `RunestoneEditorView` convenience API and module glue compiled into the framework.

See `Vendor/RunestoneEditor/README.md` for provenance and licenses.

## CI and Release

Build and test jobs run on GitHub-hosted `macos-26` (the small planning job runs on `ubuntu-latest`). Building the Tree-sitter grammars for five slices is slow, so a release is split in two: the binary is built once and published under its own tag, and package versions only point at it.

Tags:

- `upstream.<major>.<minor>.<patch>-<rev>` — binary release (`Runestone.xcframework.zip`). `<major>.<minor>.<patch>` is `RUNESTONE_VERSION` from `Upstream.versions`; `<rev>` increments on every build of the same upstream (vendored sources or build changed).
- `<major>.<minor>.<patch>` — Swift package release; `Package.swift` points at one `upstream.*` asset.
- `storage.0.1.0`, `storage.0.2.0` — legacy binary releases from before the split. Package tags `0.1.0` and `0.2.0` download from them, so they stay published; do not delete them.

Workflows:

- **Build XCFramework** — weekly (Monday 03:00 UTC) and `workflow_dispatch`. Fetches upstream, archives every slice, publishes `upstream.<version>-<rev>` (next free rev), then dispatches **Release Package** with `package_version` (input, or latest package tag + patch). The weekly run checks the newest `simonbs/Runestone` tag and only builds when it has no `upstream.*` release yet, re-pinning `Upstream.versions` and committing the bump. Manual runs build the pinned version; set `upstream_version` (`latest` or a tag) to re-pin, uncheck `release_package` to publish only the binary.
- **Release Package** — `workflow_dispatch` with `package_version` and `upstream_tag`. Downloads that binary, writes the `Package.swift` URL + checksum, runs `./Script/test.sh` against it (SwiftPM resolves the published zip), commits the manifest, and tags the package release. Never rebuilds — reuse an existing `upstream.*` tag to ship shim-only changes in minutes.
- **PR Build & Test** — runs `./Script/test.sh` against the released binary
- **UI Tests** — builds the XCFramework, then runs `Example/MobileRunestoneApp`

Local equivalent:

```bash
# Binary (Build XCFramework)
./Script/resolve-upstream.sh latest --write   # optional: re-pin simonbs/Runestone
git commit -m "upstream: simonbs/Runestone 0.5.3" Upstream.versions && git push   # pin first, so the tag below describes the binary
TAG=$(./Script/next-tag.sh upstream)          # e.g. upstream.0.5.3-1
./Script/build.sh
./Script/test.sh
gh release create "$TAG" --target "$(git rev-parse HEAD)" --latest=false \
  --title "Runestone XCFramework $TAG" --notes "simonbs/Runestone 0.5.3" build/Runestone.xcframework.zip

# Package (Release Package)
./Script/build-manifest.sh build/Runestone.xcframework.zip \
  "https://github.com/Lakr233/Runestone.xcframework/releases/download/$TAG/Runestone.xcframework.zip"
./Script/test.sh
git commit -m "release: 0.3.0 ($TAG)" Package.swift && git push
gh release create 0.3.0 --target "$(git rev-parse HEAD)" --latest --title "Runestone 0.3.0" --notes "Binary: $TAG"
```

## License

MIT. Bundled upstream components keep their original licenses (Runestone, Tree-sitter, and the individual grammars).
