import XCTest
import ChefCore
@testable import Chef

/// Smoke test do target do app: confirma que o app importa e usa o
/// ChefCore corretamente (não é um teste de UI — esses vêm na Fase 8).
final class DashboardBudgetTests: XCTestCase {
    func testRemainingBudgetMatchesDemoData() {
        let goal = DailyGoal(calories: 2100, protein: 170)
        let consumed = NutritionFacts(calories: 912, protein: 34.2, carbs: 40, fat: 20)
        let budget = NutritionEngine.calculateRemainingBudget(goal: goal, consumed: consumed)
        XCTAssertEqual(budget.caloriesRemaining, 1188)
    }
}
