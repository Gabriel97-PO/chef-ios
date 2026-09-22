import XCTest
@testable import ChefCore

final class NutrientKindTests: XCTestCase {
    func testEveryKindHasAUniqueRawValue() {
        let raws = NutrientKind.allCases.map(\.rawValue)
        XCTAssertEqual(raws.count, Set(raws).count)
    }

    func testEveryKindHasANonEmptyPortugueseLabel() {
        for kind in NutrientKind.allCases {
            XCTAssertFalse(kind.label.isEmpty, kind.rawValue)
        }
    }

    func testCoversTheFoodsMentionedInTheSpec() {
        // Só confirma que a taxonomia cobre as categorias citadas na
        // especificação — não é uma lista exaustiva, é um sanity check.
        let expected: Set<NutrientKind> = [
            .totalSugars, .saturatedFat, .transFat, .omega3, .cholesterol,
            .calcium, .iron, .potassium, .vitaminA, .vitaminD, .vitaminC, .vitaminB12,
            .choline, .taurine,
        ]
        for kind in expected {
            XCTAssertTrue(NutrientKind.allCases.contains(kind), kind.rawValue)
        }
    }
}
