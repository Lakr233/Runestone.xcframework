import Runestone
import RunestoneEditor
import RunestoneLanguageSupport
import RunestoneThemeSupport
import XCTest

final class RunestoneTests: XCTestCase {
    private static let sample = "let value = 42\nprint(value)\n"

    func testLanguageIdentifiersResolve() {
        let identifiers = [
            "swift", "python", "javascript", "typescript", "json", "markdown",
            "rust", "go", "c", "cpp", "html", "css", "yaml", "bash", "sql",
        ]
        for identifier in identifiers {
            XCTAssertNotNil(TreeSitterLanguage.language(withIdentifier: identifier), identifier)
        }
        XCTAssertNil(TreeSitterLanguage.language(withIdentifier: "not-a-language"))
    }

    func testBundledQueriesAreReadable() throws {
        let highlights = try String(contentsOf: TreeSitterSwiftQueries.highlightsFileURL)
        XCTAssertFalse(highlights.isEmpty)
    }

    func testStateParsesWithBundledLanguage() throws {
        let language = try XCTUnwrap(TreeSitterLanguage.language(withIdentifier: "swift"))
        let state = TextViewState(text: Self.sample, theme: TomorrowTheme(), language: language)
        XCTAssertNotNil(state)
    }

    @MainActor
    func testEditorAppliesThemeAndLanguage() throws {
        let textView = RunestoneEditorView.new()
        textView.text = Self.sample
        textView.apply(theme: OneDarkTheme())
        textView.apply(language: try XCTUnwrap(TreeSitterLanguage.language(withIdentifier: "swift")))
        XCTAssertEqual(textView.text, Self.sample)
        XCTAssertTrue(textView.showLineNumbers)
    }
}
