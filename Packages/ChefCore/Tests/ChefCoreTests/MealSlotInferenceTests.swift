import XCTest
@testable import ChefCore

final class MealSlotInferenceTests: XCTestCase {
    func testInfersTheObviousNames() {
        XCTAssertEqual(MealSlot.inferred(fromName: "ALMOÇO"), .almoco)
        XCTAssertEqual(MealSlot.inferred(fromName: "Café da manhã"), .cafeDaManha)
        XCTAssertEqual(MealSlot.inferred(fromName: "jantar"), .jantar)
        XCTAssertEqual(MealSlot.inferred(fromName: "Lanche"), .lanche)
        XCTAssertEqual(MealSlot.inferred(fromName: "Pós-treino"), .posTreino)
    }

    func testIgnoresAccentsAndCase() {
        XCTAssertEqual(MealSlot.inferred(fromName: "CAFE DA MANHA"), .cafeDaManha)
        XCTAssertEqual(MealSlot.inferred(fromName: "almoco"), .almoco)
    }

    /// "Lanche da manhã" contém "manha", mas é lanche — os termos mais
    /// específicos têm que ganhar dos genéricos.
    func testMoreSpecificTermsWinOverGenericOnes() {
        XCTAssertEqual(MealSlot.inferred(fromName: "Lanche da manhã"), .lanche)
        XCTAssertEqual(MealSlot.inferred(fromName: "Lanche da tarde"), .lanche)
        XCTAssertEqual(MealSlot.inferred(fromName: "Refeição pós treino"), .posTreino)
    }

    func testAcceptsCommonSynonyms() {
        XCTAssertEqual(MealSlot.inferred(fromName: "Desjejum"), .cafeDaManha)
        XCTAssertEqual(MealSlot.inferred(fromName: "Colação"), .lanche)
        XCTAssertEqual(MealSlot.inferred(fromName: "Ceia"), .jantar)
    }

    /// Nome que não casa com nada devolve nil em vez de cair em `.outro`
    /// silenciosamente — quem chama decide.
    func testUnknownNameReturnsNil() {
        XCTAssertNil(MealSlot.inferred(fromName: "Refeição livre"))
        XCTAssertNil(MealSlot.inferred(fromName: ""))
        XCTAssertNil(MealSlot.inferred(fromName: "Suplementação"))
    }
}
