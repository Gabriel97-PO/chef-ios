import XCTest
@testable import ChefCore

final class ShoppingListBuilderTests: XCTestCase {
    func testSumsQuantitiesOfTheSameNameAndUnit() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Arroz", quantity: 150, unit: .g),
            (name: "arroz", quantity: 100, unit: .g), // caixa baixa, mesmo alimento
        ])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.quantity, 250)
    }

    func testIgnoresAccentsWhenGrouping() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Café da manhã batata", quantity: 100, unit: .g),
            (name: "cafe da manha batata", quantity: 50, unit: .g),
        ])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.quantity, 150)
    }

    func testKeepsDifferentUnitsAsSeparateEntries() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Leite", quantity: 200, unit: .ml),
            (name: "Leite", quantity: 1, unit: .unidade),
        ])
        XCTAssertEqual(entries.count, 2)
    }

    func testKeepsDifferentFoodsAsSeparateEntries() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Arroz", quantity: 150, unit: .g),
            (name: "Feijão", quantity: 100, unit: .g),
        ])
        XCTAssertEqual(entries.count, 2)
    }

    func testDropsZeroOrNegativeQuantities() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Arroz", quantity: 0, unit: .g),
            (name: "Feijão", quantity: -10, unit: .g),
        ])
        XCTAssertTrue(entries.isEmpty)
    }

    func testPreservesFirstSeenOrder() {
        let entries = ShoppingListBuilder.aggregate([
            (name: "Zebra", quantity: 1, unit: .unidade),
            (name: "Abacaxi", quantity: 1, unit: .unidade),
        ])
        XCTAssertEqual(entries.map(\.name), ["Zebra", "Abacaxi"])
    }

    func testFromFixedMealsAggregatesAcrossMultipleMeals() {
        let almoco = FixedMeal(name: "Almoço", items: [
            FoodEntry(name: "Arroz", quantity: 150, unit: .g, nutrition: .zero),
            FoodEntry(name: "Frango", quantity: 120, unit: .g, nutrition: .zero),
        ])
        let janta = FixedMeal(name: "Janta", items: [
            FoodEntry(name: "Arroz", quantity: 100, unit: .g, nutrition: .zero),
        ])
        let entries = ShoppingListBuilder.fromFixedMeals([almoco, janta])
        XCTAssertEqual(entries.first { normalizeText($0.name) == "arroz" }?.quantity, 250)
    }

    func testFromRecipesAggregatesIngredients() {
        let recipe = Recipe(name: "Crepioca", ingredients: [
            RecipeIngredient(name: "Ovo", quantity: 2, unit: .unidade, nutrition: .zero),
            RecipeIngredient(name: "Tapioca", quantity: 30, unit: .g, nutrition: .zero),
        ], servings: 1)
        let entries = ShoppingListBuilder.fromRecipes([recipe])
        XCTAssertEqual(entries.count, 2)
    }
}
