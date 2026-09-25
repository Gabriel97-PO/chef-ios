import XCTest
@testable import Chef

/// Teste de integração real contra o Open Food Facts — sem mock, de
/// propósito. A busca online (roadmap: "deverá ser realizada uma pesquisa
/// em algum lugar") já quebrou silenciosamente uma vez por causa de um
/// detalhe de serialização da API real (campos numéricos que às vezes vêm
/// como string) que nenhum teste com JSON fixo nosso pegaria — só bater na
/// API de verdade garante que o parsing aguenta o formato real dela. O
/// runner do CI tem internet; se a rede cair, o teste falha claramente em
/// vez de mascarar uma regressão.
final class OpenFoodFactsServiceTests: XCTestCase {
    func testSearchReturnsDecodedResultsFromTheRealAPI() async throws {
        let results = try await OpenFoodFactsService.search("banana")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { !$0.name.isEmpty && $0.per100g.calories > 0 })
    }

    /// Termo com acento — cobre o caso de um erro de codificação de URL
    /// silenciosamente devolver zero resultados em vez de lançar erro.
    func testSearchHandlesAccentedPortugueseTerms() async throws {
        let results = try await OpenFoodFactsService.search("feijão")
        XCTAssertFalse(results.isEmpty)
    }
}
