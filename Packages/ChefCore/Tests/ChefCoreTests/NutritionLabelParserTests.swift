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

    // MARK: - Nutrientes estendidos (seção 5)

    func testParsesTheExtendedNutrientsThatCommonlyAppearOnRealLabels() {
        let lines = [
            line("Açúcares totais 8 g"),
            line("Açúcares adicionados 5 g"),
            line("Gorduras saturadas 1 g"),
            line("Gorduras trans 0 g"),
            line("Cálcio 120 mg"),
            line("Ferro 2 mg"),
        ]
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertEqual(result.extendedNutrients[.totalSugars]?.value, 8)
        XCTAssertEqual(result.extendedNutrients[.addedSugars]?.value, 5)
        XCTAssertEqual(result.extendedNutrients[.saturatedFat]?.value, 1)
        XCTAssertEqual(result.extendedNutrients[.transFat]?.value, 0)
        XCTAssertEqual(result.extendedNutrients[.calcium]?.value, 120)
        XCTAssertEqual(result.extendedNutrients[.iron]?.value, 2)
    }

    /// A regra "nil ≠ zero" (seção 6) vale igual pro dicionário estendido:
    /// declarado como zero fica com a chave presente e valor 0; nunca
    /// declarado simplesmente não entra no dicionário.
    func testDeclaredZeroVersusNotDeclaredInExtendedNutrients() {
        let lines = [line("Gorduras trans 0 g")] // "açúcares" nem aparece
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertNotNil(result.extendedNutrients[.transFat])
        XCTAssertEqual(result.extendedNutrients[.transFat]?.value, 0)
        XCTAssertNil(result.extendedNutrients[.totalSugars])
    }

    func testExtendedAndCoreFieldsDoNotStealEachOthersNumbers() {
        let lines = [
            line("Carboidratos 22 g"),
            line("Açúcares totais 8 g"),
            line("Gorduras totais 2 g"),
            line("Gorduras saturadas 1 g"),
        ]
        let result = NutritionLabelParser.parse(lines: lines)

        XCTAssertEqual(result.carbs?.value, 22)
        XCTAssertEqual(result.extendedNutrients[.totalSugars]?.value, 8)
        XCTAssertEqual(result.fat?.value, 2)
        XCTAssertEqual(result.extendedNutrients[.saturatedFat]?.value, 1)
    }
}
