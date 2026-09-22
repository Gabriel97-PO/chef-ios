import XCTest
@testable import ChefCore

final class FoodFitAnalyzerTests: XCTestCase {
    func testFitsWhenSmallShareOfBudget() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let result = FoodFitAnalyzer.analyze(FoodFitInput(
            nutrition: NutritionFacts(calories: 120, protein: 24, carbs: 3, fat: 2),
            dailyGoal: goal,
            consumedToday: .zero
        ))
        XCTAssertEqual(result.status, .fits)
        XCTAssertEqual(result.caloriesRemaining, 2100)
        XCTAssertEqual(result.title, "Pode sim.")
    }

    func testDoesNotFitWhenExceedsRemaining() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let result = FoodFitAnalyzer.analyze(FoodFitInput(
            nutrition: NutritionFacts(calories: 900, protein: 10, carbs: 100, fat: 20),
            dailyGoal: goal,
            consumedToday: NutritionFacts(calories: 1800, protein: 100, carbs: 0, fat: 0)
        ))
        XCTAssertEqual(result.status, .doesNotFit)
        XCTAssertEqual(result.caloriesRemaining, 300)
        XCTAssertEqual(result.title, "Agora não seria a melhor escolha.")
    }

    func testAttentionWhenLargeShareOfRemainingBudget() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let result = FoodFitAnalyzer.analyze(FoodFitInput(
            nutrition: NutritionFacts(calories: 500, protein: 40, carbs: 20, fat: 10),
            dailyGoal: goal,
            consumedToday: NutritionFacts(calories: 1200, protein: 100, carbs: 0, fat: 0)
        ))
        XCTAssertEqual(result.status, .attention)
        XCTAssertEqual(result.title, "Pode, mas com atenção.")
    }

    func testNeverUsesJudgmentalLanguage() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let result = FoodFitAnalyzer.analyze(FoodFitInput(
            nutrition: NutritionFacts(calories: 900, protein: 10, carbs: 100, fat: 20),
            dailyGoal: goal,
            consumedToday: NutritionFacts(calories: 1800, protein: 100, carbs: 0, fat: 0)
        ))
        let lowered = (result.title + " " + result.message).lowercased()
        for forbidden in ["ruim", "proibido", "saudável", "lixo", "não deveria"] {
            XCTAssertFalse(lowered.contains(forbidden), forbidden)
        }
    }

    /// A mesma entrada, com ou sem refeição/prescrição associada, tem que
    /// produzir o mesmo resultado matemático — o motor é único pra
    /// alimento, produto, prato, receita e refeição (seção 13).
    func testSameNutritionProducesSameVerdictRegardlessOfMealSlot() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let nutrition = NutritionFacts(calories: 400, protein: 30, carbs: 20, fat: 10)

        let withoutSlot = FoodFitAnalyzer.analyze(FoodFitInput(nutrition: nutrition, dailyGoal: goal, consumedToday: .zero))
        let withSlot = FoodFitAnalyzer.analyze(FoodFitInput(nutrition: nutrition, dailyGoal: goal, consumedToday: .zero, mealSlot: .almoco))

        XCTAssertEqual(withoutSlot.status, withSlot.status)
        XCTAssertEqual(withoutSlot.message, withSlot.message)
    }
}
