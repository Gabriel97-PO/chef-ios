import XCTest
@testable import ChefCore

final class ScanFramingTests: XCTestCase {
    /// view e imagem do mesmo tamanho: sem aspect-fill nenhum pra corrigir,
    /// o retângulo da view deve mapear 1:1 pro retângulo da imagem.
    func testIdentityWhenViewAndImageMatch() {
        let viewSize = CGSize(width: 400, height: 800)
        let viewRect = CGRect(x: 50, y: 100, width: 300, height: 400)
        let result = ScanFraming.imageRect(forViewRect: viewRect, viewSize: viewSize, imageSize: viewSize)
        XCTAssertEqual(result, viewRect)
    }

    /// Imagem mais "quadrada" (3:4) numa tela bem mais alta (9:19.5, tipo
    /// iPhone): o resizeAspectFill estica pela altura e corta as laterais
    /// da imagem — o centro da view tem que continuar mapeando pro centro
    /// da imagem.
    func testCentersOnPortraitPhoneScreen() {
        let viewSize = CGSize(width: 390, height: 844)
        let imageSize = CGSize(width: 3024, height: 4032) // 3:4, típico de foto
        let center = CGRect(x: viewSize.width / 2 - 1, y: viewSize.height / 2 - 1, width: 2, height: 2)

        let result = ScanFraming.imageRect(forViewRect: center, viewSize: viewSize, imageSize: imageSize)

        XCTAssertEqual(result.midX, imageSize.width / 2, accuracy: 5)
        XCTAssertEqual(result.midY, imageSize.height / 2, accuracy: 5)
    }

    /// O retângulo mapeado nunca pode passar dos limites da imagem, mesmo
    /// que a moldura da tela encoste na borda da tela.
    func testNeverExceedsImageBounds() {
        let viewSize = CGSize(width: 390, height: 844)
        let imageSize = CGSize(width: 3024, height: 4032)
        let fullView = CGRect(origin: .zero, size: viewSize)

        let result = ScanFraming.imageRect(forViewRect: fullView, viewSize: viewSize, imageSize: imageSize)

        XCTAssertGreaterThanOrEqual(result.minX, 0)
        XCTAssertGreaterThanOrEqual(result.minY, 0)
        XCTAssertLessThanOrEqual(result.maxX, imageSize.width)
        XCTAssertLessThanOrEqual(result.maxY, imageSize.height)
    }

    func testDefaultGuideRectIsCenteredAndPortrait() {
        let viewSize = CGSize(width: 390, height: 844)
        let guide = ScanFraming.defaultGuideRect(in: viewSize)

        XCTAssertEqual(guide.midX, viewSize.width / 2, accuracy: 0.5)
        XCTAssertGreaterThan(guide.height, guide.width) // portrait, como uma tabela nutricional
        XCTAssertLessThan(guide.width, viewSize.width)
        XCTAssertLessThan(guide.height, viewSize.height)
    }

    func testDegenerateSizesFallBackToFullImageInsteadOfCrashing() {
        let result = ScanFraming.imageRect(forViewRect: .zero, viewSize: .zero, imageSize: CGSize(width: 100, height: 200))
        XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 100, height: 200))
    }
}
