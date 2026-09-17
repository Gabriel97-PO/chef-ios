import XCTest

/// Captura as telas no tema escuro, onde a identidade do app troca de
/// laranja para preto + verde neon (roadmap item 9).
///
/// Classe separada de propósito: `XCUIDevice.shared.appearance = .dark` não
/// surte efeito nos runners do GitHub Actions (o app sobe no tema claro de
/// qualquer jeito), então quem troca a aparência é o `xcrun simctl ui
/// booted appearance dark` no workflow, que roda só esta classe. Se ela
/// rodasse junto com as outras, fotografaria o tema errado.
final class DarkModeScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureMainScreensDark() throws {
        let app = XCUIApplication()
        app.launch()

        attachScreenshot(app, name: "10-dark-hoje")

        for (tabLabel, fileName) in [("Dieta", "11-dark-dieta"), ("Histórico", "12-dark-historico"), ("Perfil", "13-dark-perfil")] {
            let tab = app.buttons[tabLabel]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
                sleep(1)
            }
            attachScreenshot(app, name: fileName)
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
