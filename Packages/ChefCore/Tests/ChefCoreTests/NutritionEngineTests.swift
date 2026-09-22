import XCTest
@testable import ChefCore

final class NutritionEngineTests: XCTestCase {

    func testCalculatePortionScalesProportionally() {
        let rap10 = Food(
            name: "Rap10", baseUnit: .g, baseQuantity: 100,
            nutrition: NutritionFacts(calories: 300, protein: 8, carbs: 45, fat: 9),
            isCustom: false, source: .seed
        )
        let result = NutritionEngine.calculatePortion(food: rap10, quantity: 60)
        XCTAssertEqual(result.calories, 180)
        XCTAssertEqual(result.protein, 4.8)
    }

    func testCalculatePortionZeroQuantity() {
        let rap10 = Food(name: "Rap10", baseUnit: .g, baseQuantity: 100, nutrition: NutritionFacts(calories: 300, protein: 8, carbs: 45, fat: 9), isCustom: false, source: .seed)
        XCTAssertEqual(NutritionEngine.calculatePortion(food: rap10, quantity: 0).calories, 0)
    }

    // A pergunta "isso cabe na dieta?" mudou de dono: ver
    // FoodFitAnalyzerTests.swift — testes de análise de encaixe ficam lá,
    // junto do FoodFitAnalyzer (seção 13 da especificação "Será que eu
    // posso?": "uma única inteligência de decisão nutricional").

    func testValidateNutritionCoherenceAcceptsConsistentValues() {
        XCTAssertNil(NutritionEngine.validateNutritionCoherence(NutritionFacts(calories: 220, protein: 18, carbs: 15, fat: 9)))
    }

    func testValidateNutritionCoherenceFlagsInconsistentValues() {
        XCTAssertNotNil(NutritionEngine.validateNutritionCoherence(NutritionFacts(calories: 80, protein: 15, carbs: 15, fat: 15)))
    }

    func testCalculateRecipePerServingDividesByServings() {
        let recipe = Recipe(
            name: "Teste", ingredients: [
                RecipeIngredient(name: "A", quantity: 100, unit: .g, nutrition: NutritionFacts(calories: 200, protein: 20, carbs: 10, fat: 5)),
            ],
            servings: 2
        )
        let perServing = NutritionEngine.calculateRecipePerServing(recipe)
        XCTAssertEqual(perServing.calories, 100)
        XCTAssertEqual(perServing.protein, 10)
    }

    func testCalculateWeightAverageMatchesKnownSequence() {
        let values: [Double] = [120.8, 120.4, 120.7, 120.1, 119.9, 120.2, 119.8]
        let entries = values.enumerated().map { WeightEntry(date: "2026-01-0\($0.offset + 1)", weightKg: $0.element) }
        XCTAssertEqual(NutritionEngine.calculateWeightAverage(entries, windowSize: 7)!, 120.27, accuracy: 0.01)
    }

    func testCalculateWeightAverageEmptyReturnsNil() {
        XCTAssertNil(NutritionEngine.calculateWeightAverage([]))
    }

    func testCalculateWeightChange() {
        let entries = [
            WeightEntry(date: "2026-01-01", weightKg: 120),
            WeightEntry(date: "2026-01-07", weightKg: 118.5),
        ]
        XCTAssertEqual(NutritionEngine.calculateWeightChange(entries), -1.5)
    }
}
