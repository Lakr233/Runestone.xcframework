import XCTest

#if canImport(UIKit)
    import UIKit

    #if targetEnvironment(macCatalyst)
        import AppKit
    #endif

    final class MobileRunestoneAppUITests: XCTestCase {
        private var app: XCUIApplication!

        override func setUpWithError() throws {
            continueAfterFailure = false
            app = XCUIApplication()
            app.launchArguments = ["--ui-testing"]
            installSystemAlertHandler()
            #if !targetEnvironment(macCatalyst)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    XCUIDevice.shared.orientation = .landscapeLeft
                }
            #endif
            app.launch()
        }

        override func tearDownWithError() throws {
            capture("final-state")
            app = nil
        }

        func testEditorUserOperations() throws {
            let editor = try requireEditor()
            capture("01-launch")

            XCTAssertTrue(editor.waitForExistence(timeout: 4))
            tapEditor(in: editor)
            capture("02-focused")

            typeEditorText("let value = 42\n", in: editor)
            capture("03-typed")

            let themeButton = app.buttons["editor.themeButton"].firstMatch
            if themeButton.waitForExistence(timeout: 2), themeButton.isHittable {
                themeButton.tap()
                capture("04-theme-menu")
                let oneDark = app.buttons["One Dark"].firstMatch
                if oneDark.waitForExistence(timeout: 2), oneDark.isHittable {
                    oneDark.tap()
                    capture("05-theme-one-dark")
                }
            }

            let languageButton = app.buttons["editor.languageButton"].firstMatch
            if languageButton.waitForExistence(timeout: 2), languageButton.isHittable {
                languageButton.tap()
                capture("06-language-menu")
                let python = app.buttons["python"].firstMatch
                if python.waitForExistence(timeout: 2), python.isHittable {
                    python.tap()
                    capture("07-language-python")
                }
            }
        }

        private func installSystemAlertHandler() {
            addUIInterruptionMonitor(withDescription: "System alert") { alert in
                let preferredButtons = [
                    "OK", "Ok", "好", "确定", "允许", "Allow", "继续", "Continue",
                    "关闭", "Close", "Dismiss",
                ]
                for title in preferredButtons {
                    let button = alert.buttons[title].firstMatch
                    if button.exists {
                        self.activateInterruptionButton(button)
                        return true
                    }
                }
                let firstButton = alert.buttons.firstMatch
                guard firstButton.exists else { return false }
                self.activateInterruptionButton(firstButton)
                return true
            }
        }

        private func activateInterruptionButton(_ button: XCUIElement) {
            #if targetEnvironment(macCatalyst)
                button.click()
            #else
                button.tap()
            #endif
        }

        private func requireEditor() throws -> XCUIElement {
            let editor = app.descendants(matching: .any)["editor.surface"].firstMatch
            if editor.waitForExistence(timeout: 4) {
                return editor
            }
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 8))
            return window
        }

        private func tapEditor(in element: XCUIElement) {
            let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            #if targetEnvironment(macCatalyst)
                coordinate.click()
            #else
                coordinate.tap()
            #endif
        }

        private func typeEditorText(_ text: String, in element: XCUIElement) {
            tapEditor(in: element)
            app.typeText(text)
        }

        private func capture(_ name: String) {
            guard let app else { return }
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
#endif
