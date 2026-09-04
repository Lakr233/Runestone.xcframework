# Maintaining Runestone.xcframework

Everything here is for whoever builds and releases this package. Consumers only need [README.md](README.md).

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
3. Writes `build/Runestone.xcodeproj` (`MACH_O_TYPE = staticlib`) and archives iOS, iOS Simulator, Mac Catalyst, visionOS, and visionOS Simulator
4. Emits `BinaryTarget/Runestone.xcframework` and `build/Runestone.xcframework.zip`

`build.sh` rewrites `Package.swift` to point at the local `BinaryTarget/`. `Script/build-manifest.sh` writes the release manifest from `Package.swift.template`; keep the two manifests in sync when editing products or targets.

## Compile Test

```bash
./Script/test.sh
```

Builds every product for each platform slice, the example app for iOS, iOS Simulator, and Mac Catalyst, then runs `Tests/RunestoneTests` on Mac Catalyst. It links whatever `Package.swift` points at: the released binary on a fresh checkout, `BinaryTarget/` after `./Script/build.sh`.

`Script/verify-xcframework.sh` runs inside `build.sh` and fails if a slice is not an `ar archive`, so an accidental return to `mh_dylib` cannot ship.

## Why the framework is static

`MACH_O_TYPE = staticlib` (set in `Script/assemble.py`). Two consequences shape the code:

- **Resources.** Xcode copies `Runestone.framework` into `YourApp.app/Frameworks` with an empty stub binary and the resources intact (~436 KB). `Bundle(for:)` now resolves to whatever binary linked Runestone, not to that framework, so `Sources/FrameworkSupport/BundleModule.swift` walks `privateFrameworksURL` / the sibling directory to find it. `assemble.py` rewrites upstream `L10n.swift` onto the same lookup.
- **libc++.** The static archive leaves ~40 C++ symbols undefined and records no autolink hint for them, so every product that vends Runestone carries `.linkedLibrary("c++")`.

## Do not add a `.dynamic` SPM product

Tried and measured; it does not work. Swift autolinking emits `-framework Runestone` into every object that references a Runestone type, so the static archive is pulled into each importing binary no matter what a dynamic product does:

- A `.dynamic` product over the plain `@_exported import` shims ships **empty** (116 KB, zero Runestone symbols) because the shims reference nothing, while the app binary gets the full ~77 MB.
- Adding a target that touches one type to anchor the archive gives the framework 1012 symbols *and* leaves 412 in the app — `_ts_parser_new` in the dylib, `_tree_sitter_swift` in the app. Duplication, not deduplication.

There is no non-`unsafeFlags` way to force-load the archive, and `unsafeFlags` is rejected in a package consumed as a dependency. A genuine dynamic option needs a second, dynamically linked XCFramework published alongside the static one, with its own binary target and its own shim targets.

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
git commit -m "release: 0.3.1 ($TAG)" Package.swift && git push
gh release create 0.3.1 --target "$(git rev-parse HEAD)" --latest --title "Runestone 0.3.1" --notes "Binary: $TAG"
```
