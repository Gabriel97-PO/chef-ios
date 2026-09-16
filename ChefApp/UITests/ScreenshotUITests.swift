import XCTest

/// Não é um teste de asserção — é a forma que encontrei de ver as telas do
/// Chef de verdade sem ter Xcode/simulador local: navega pelas abas e
/// anexa um screenshot de cada, extraído do .xcresult no CI (ver
/// .github/workflows/build.yml). "xcrun simctl openurl" pra deep link
/// disparava um alerta de sistema que travava sem interação — tocar direto
/// nos botões da tab bar via XCUITest não tem esse problema.
final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launch()

        attachScreenshot(app, name: "01-hoje")

        for (tabLabel, fileName) in [("Dieta", "02-dieta"), ("Scan", "03-scan"), ("Histórico", "04-historico"), ("Perfil", "05-perfil")] {
            let tab = app.buttons[tabLabel]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
                sleep(1)
            }
            attachScreenshot(app, name: fileName)
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
