import Foundation
import UIKit

public typealias RunestoneEditorView = TextView

public class BasicCharacterPair: CharacterPair {
    public let leading: String
    public let trailing: String

    public init(leading: String, trailing: String) {
        self.leading = leading
        self.trailing = trailing
    }
}

public extension RunestoneEditorView {
    static func new() -> Self {
        let `self` = Self()

        self.backgroundColor = .clear
        self.contentInsetAdjustmentBehavior = .always

        self.showTabs = true
        self.showSpaces = true
        self.showLineBreaks = true
        self.showLineNumbers = true
        self.showSoftLineBreaks = true
        self.showNonBreakingSpaces = true

        self.isLineWrappingEnabled = true

        self.autocorrectionType = .no
        self.autocapitalizationType = .none
        self.smartDashesType = .no
        self.smartQuotesType = .no
        self.smartInsertDeleteType = .no

        self.kern = 0.3
        self.lineHeightMultiplier = 1.2
        self.verticalOverscrollFactor = 0.25
        self.gutterMinimumCharacterCount = 3

        self.indentStrategy = .space(length: 4)
        self.textContainerInset = .init(top: 8, left: 4, bottom: 8, right: 4)

        self.characterPairs = [
            BasicCharacterPair(leading: "(", trailing: ")"),
            BasicCharacterPair(leading: "{", trailing: "}"),
            BasicCharacterPair(leading: "[", trailing: "]"),
            BasicCharacterPair(leading: "\"", trailing: "\""),
            BasicCharacterPair(leading: "'", trailing: "'"),
        ]
        return self
    }

    func apply(language: TreeSitterLanguage) {
        setState(.init(text: text, language: language))
    }

    func applyAsync(language: TreeSitterLanguage, text: String, completion: @escaping () -> Void) {
        Task.detached {
            let state = TextViewState(text: text, language: language)
            await MainActor.run {
                self.setState(state)
                completion()
            }
        }
    }

    func apply(theme: Theme) {
        setState(.init(text: text, theme: theme))
    }
}

public extension TreeSitterLanguage {
    static func language(withIdentifier identifier: String) -> TreeSitterLanguage? {
        switch identifier.lowercased() {
        case "astro": TreeSitterLanguage.astro
        case "bash": TreeSitterLanguage.bash
        case "cpp", "c++": TreeSitterLanguage.cpp
        case "c": TreeSitterLanguage.c
        case "css": TreeSitterLanguage.css
        case "csharp": TreeSitterLanguage.cSharp
        case "comment": TreeSitterLanguage.comment
        case "elixir": TreeSitterLanguage.elixir
        case "elm": TreeSitterLanguage.elm
        case "go": TreeSitterLanguage.go
        case "html": TreeSitterLanguage.html
        case "haskell": TreeSitterLanguage.haskell
        case "jsdoc": TreeSitterLanguage.jsDoc
        case "json5": TreeSitterLanguage.json5
        case "json": TreeSitterLanguage.json
        case "java": TreeSitterLanguage.java
        case "javascript": TreeSitterLanguage.javaScript
        case "julia": TreeSitterLanguage.julia
        case "latex": TreeSitterLanguage.latex
        case "lua": TreeSitterLanguage.lua
        case "markdowninline": TreeSitterLanguage.markdownInline
        case "markdown", "md": TreeSitterLanguage.markdown
        case "ocaml": TreeSitterLanguage.ocaml
        case "php": TreeSitterLanguage.php
        case "perl": TreeSitterLanguage.perl
        case "python": TreeSitterLanguage.python
        case "r": TreeSitterLanguage.r
        case "regex": TreeSitterLanguage.regex
        case "ruby": TreeSitterLanguage.ruby
        case "rust": TreeSitterLanguage.rust
        case "scss": TreeSitterLanguage.scss
        case "sql": TreeSitterLanguage.sql
        case "svelte": TreeSitterLanguage.svelte
        case "swift": TreeSitterLanguage.swift
        case "toml": TreeSitterLanguage.toml
        case "tsx": TreeSitterLanguage.tsx
        case "typescript": TreeSitterLanguage.typeScript
        case "yaml": TreeSitterLanguage.yaml
        default:
            nil
        }
    }
}
