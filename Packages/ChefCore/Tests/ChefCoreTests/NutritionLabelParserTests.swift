import XCTest
@testable import ChefCore

final class NutritionLabelParserTests: XCTestCase {

    private func line(_ text: String, _ confidence: Double = 0.95) -> OCRLine {
        OCRLine(text: text, confidence: confidence)
    }

    func testParsesSingleColumnLabelAndNumberOnSameLine() {
        let lines = [
            line("Porção 30 g"),
            line("Valor energético 120 kcal"),
            line("Carboidratos 22 g"),
            line("Proteínas 3 g"),
            line("Gorduras totais 2 g"),
            line("Fibra alimentar 1,5 g"),
            line("Sódio 120 mg"),
        ]
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertEqual(result.portionSize?.value, 30)
        XCTAssertEqual(result.portionUnit, .g)
        XCTAssertEqual(result.calories?.value, 120)
        XCTAssertEqual(result.carbs?.value, 22)
        XCTAssertEqual(result.protein?.value, 3)
        XCTAssertEqual(result.fat?.value, 2)
        XCTAssertEqual(result.fiber?.value, 1.5)
        XCTAssertEqual(result.sodium?.value, 120)
    }

    func testHandlesBrazilianDecimalComma() {
        let lines = [line("Proteínas 6,5 g")]
        let result = NutritionLabelParser.parse(lines: lines)
        XCTAssertEqual(result.protein?.value, 6.5)
    }

    func testFallsBackToPairingWhenLabelsAndNumbersAreInSeparateColumns() {
        // Layout comum: o OCR lê a coluna de números inteira, depois a coluna de rótulos.
        let lines = [
            line("120"), line("22"), line("3"),
            line("Valor energético"), line("Carboidratos"), line("Proteínas"),
        ]
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertEqual(result.calories?.value, 120)
        XCTAssertEqual(result.carbs?.value, 22)
        XCTAssertEqual(result.protein?.value, 3)
    }

    func testNeverInventsAFieldThatWasNotOnTheLabel() {
        let lines = [line("Porção 30 g"), line("Valor energético 120 kcal")]
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertEqual(result.calories?.value, 120)
        XCTAssertNil(result.sodium) // não apareceu na embalagem — nunca vira 0
        XCTAssertNil(result.fiber)
    }

    func testDistinguishesPer100gFromServingBasis() {
        let per100 = NutritionLabelParser.parse(lines: [line("100 g"), line("Valor energético 350 kcal")])
        XCTAssertEqual(per100.nutritionBasis, .per100g)

        let perServing = NutritionLabelParser.parse(lines: [line("Porção 30 g"), line("Valor energético 120 kcal")])
        XCTAssertEqual(perServing.nutritionBasis, .serving)
    }

    func testFieldConfidenceReflectsTheOcrLineConfidenceNotAFixedValue() {
        let lines = [line("Valor energético 120 kcal", 0.42)]
        let result = NutritionLabelParser.parse(lines: lines)
        XCTAssertEqual(result.calories?.confidence, 0.42)
        XCTAssertEqual(confidenceTier(result.calories?.confidence), .unrecognized)
    }
}
