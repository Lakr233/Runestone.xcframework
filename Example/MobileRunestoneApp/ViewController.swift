import RunestoneEditor
import UIKit

final class ViewController: UIViewController {
    private static let themeKey = "SelectedTheme"
    private static let languageKey = "SelectedLanguage"
    private static let sampleText = """
    import Foundation

    struct Hello {
        let name: String

        func greet() {
            print("Hello, \\(name)")
        }
    }

    Hello(name: "Runestone").greet()
    """

    private let textView = RunestoneEditorView.new()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Runestone"
        view.backgroundColor = .systemBackground
        configureEditor()
        configureMenus()
        applySavedState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    private func configureEditor() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isAccessibilityElement = true
        textView.accessibilityIdentifier = "editor.surface"
        textView.accessibilityLabel = "Editor"
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    private func configureMenus() {
        let languageItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
            menu: buildLanguageMenu()
        )
        languageItem.accessibilityIdentifier = "editor.languageButton"

        let themeItem = UIBarButtonItem(
            image: UIImage(systemName: "paintpalette"),
            menu: buildThemeMenu()
        )
        themeItem.accessibilityIdentifier = "editor.themeButton"

        navigationItem.rightBarButtonItems = [themeItem, languageItem]
    }

    private func applySavedState() {
        apply(theme: savedTheme())
        let language = UserDefaults.standard.string(forKey: Self.languageKey) ?? "swift"
        apply(languageIdentifier: language, text: textView.text.isEmpty ? Self.sampleText : textView.text)
    }

    private func savedTheme() -> Theme {
        switch UserDefaults.standard.string(forKey: Self.themeKey) {
        case "One Dark":
            OneDarkTheme()
        case "Plain Text":
            PlainTextTheme()
        default:
            TomorrowTheme(size: 14)
        }
    }

    private func apply(theme: Theme) {
        textView.apply(theme: theme)
        if let editorTheme = theme as? EditorTheme {
            view.backgroundColor = editorTheme.backgroundColor
        }
    }

    private func apply(languageIdentifier: String, text: String) {
        UserDefaults.standard.set(languageIdentifier, forKey: Self.languageKey)
        title = languageIdentifier
        if let language = TreeSitterLanguage.language(withIdentifier: languageIdentifier) {
            textView.applyAsync(language: language, text: text) {}
        } else {
            textView.text = text
        }
    }

    private func buildThemeMenu() -> UIMenu {
        let actions = ["Tomorrow", "One Dark", "Plain Text"].map { name in
            UIAction(title: name) { [weak self] _ in
                UserDefaults.standard.set(name, forKey: Self.themeKey)
                self?.apply(theme: self?.savedTheme() ?? TomorrowTheme(size: 14))
            }
        }
        return UIMenu(title: "Theme", children: actions)
    }

    private func buildLanguageMenu() -> UIMenu {
        let languages = [
            "swift", "python", "javascript", "typescript", "json", "markdown",
            "rust", "go", "c", "cpp", "html", "css", "yaml", "bash", "sql",
        ]
        let actions = languages.map { identifier in
            UIAction(title: identifier) { [weak self] _ in
                guard let self else { return }
                self.apply(languageIdentifier: identifier, text: self.textView.text)
            }
        }
        return UIMenu(title: "Language", children: actions)
    }
}
