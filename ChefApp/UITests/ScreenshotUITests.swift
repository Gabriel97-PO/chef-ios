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
        waitForSplash(app)

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

    /// Abre o detalhe de uma refeição do dia. É onde aparecem o que a dieta
    /// prescreve pra aquele horário (roadmap item 5) e o campo pra registrar
    /// alimento no dia (item 7) — nenhum dos dois é alcançável pelos
    /// screenshots das abas principais.
    func testCaptureMealDetail() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSplash(app)

        // O card do almoço é o que recebe a dieta importada pelo outro teste.
        let almoco = app.staticTexts["Almoço"]
        guard almoco.waitForExistence(timeout: 5) else { return }
        almoco.tap()
        sleep(1)
        attachScreenshot(app, name: "14-refeicao-detalhe")

        let addButton = app.buttons["Adicionar alimento"]
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            sleep(1)
            attachScreenshot(app, name: "15-refeicao-adicionar")
        }
    }

    /// Percorre o fluxo de importação de dieta (CNP) de ponta a ponta e
    /// captura cada etapa: colar texto, processando, revisão e aplicado.
    /// Complementa `testCaptureMainScreens`, que só navega pelas abas
    /// principais e não abre o sheet de importação.
    func testCaptureDietImportFlow() throws {
        let app = XCUIApplication()
        app.launch()
        waitForSplash(app)

        let dietaTab = app.buttons["Dieta"]
        guard dietaTab.waitForExistence(timeout: 5) else { return }
        dietaTab.tap()

        let importButton = app.buttons["Importar"]
        guard importButton.waitForExistence(timeout: 5) else { return }
        importButton.tap()

        let textEditor = app.textViews.firstMatch
        guard textEditor.waitForExistence(timeout: 5) else { return }
        textEditor.tap()
        textEditor.typeText("PACIENTE: Gabriel\n\nCALORIAS: 2100\nPROTEÍNA: 170\n\nALMOÇO\n150 g arroz\n200 g peito de frango\nOU\n200 g batata doce")
        attachScreenshot(app, name: "06-import-texto")

        let analyzeButton = app.buttons["Analisar dieta"]
        guard analyzeButton.waitForExistence(timeout: 5) else { return }
        analyzeButton.tap()
        attachScreenshot(app, name: "07-import-processando")

        let applyButton = app.buttons["Aplicar dieta"]
        guard applyButton.waitForExistence(timeout: 5) else { return }
        sleep(1)
        attachScreenshot(app, name: "08-import-revisao")

        applyButton.tap()

        let seeMyDietButton = app.buttons["Ver minha dieta"]
        _ = seeMyDietButton.waitForExistence(timeout: 5)
        attachScreenshot(app, name: "09-import-aplicado")
    }

    /// Espera a `ChefLoadingView` sumir antes de mexer na tela. Nem
    /// `waitForExistence` nem `isHittable` servem aqui: o `RootTabView` já
    /// existe por baixo da splash desde o primeiro instante (só coberto
    /// visualmente por um `ZStack`), e o `Color` que cobre a tela durante a
    /// splash não é um elemento de acessibilidade — o XCUITest não percebe
    /// que ele está bloqueando o toque, então `isHittable` dá falso positivo
    /// antes da animação acabar. A duração da sequência é 100% determinística
    /// (soma dos `sleep` em `ChefLoadingView.runSequence`, ~3.4s), então uma
    /// espera fixa com folga é mais confiável que tentar inferir pela UI.
    private func waitForSplash(_ app: XCUIApplication) {
        _ = app.buttons["Hoje"].waitForExistence(timeout: 8)
        sleep(4)
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
