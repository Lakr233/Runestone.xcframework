# Vendor/RunestoneEditor

Sources that used to be pulled from the `Lakr233/RunestoneEditor` package. That
repository no longer exists, so the parts the XCFramework needs are vendored
here verbatim from its `External/` directory at commit
`29c5c27c9d62932bc388aa143dd2a99f96799630` (imported 2026-09-01).

`Script/assemble.py` reads these trees; nothing here is a Swift package on its own.

| Directory | What it is | Origin | License |
| --- | --- | --- | --- |
| `TreeSitter/Sources/TreeSitter` | Tree-sitter runtime (`lib/src`, `lib/include`) | [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter) | MIT, Max Brunsfeld (`TreeSitter/LICENSE`) |
| `RunestoneLanguageSupport/Sources` | Grammars (`parser.c`, scanners), highlight/injection/indent queries, and `TreeSitter*Runestone` bindings | [simonbs/TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) | MIT, Simon Støvring (`RunestoneLanguageSupport/LICENSE`); each grammar keeps its own license |
| `RunestoneThemeSupport/Sources` | Tomorrow, One Dark, and Plain Text themes | [simonbs/Runestone](https://github.com/simonbs/Runestone) `Example/Themes` | MIT, Simon Støvring |

The `RunestoneEditorView` convenience API is not vendored; it lives in
`Sources/FrameworkSupport/RunestoneEditor.swift`.

## Updating

Replace the relevant `Sources` tree, run `./Script/build.sh --platforms iossimulator --skip-tests`
to check that `assemble.py` still flattens it, then dispatch **Build XCFramework**.
The binary release gets a new `upstream.<version>-<rev>` tag even though the
pinned `simonbs/Runestone` version did not change.
