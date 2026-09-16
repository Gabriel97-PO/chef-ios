import Foundation

public struct RecipeIngredient: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var foodId: String?
    public var name: String
    public var quantity: Double
    public var unit: PortionUnit
    public var nutrition: NutritionFacts

    public init(id: String = UUID().uuidString, foodId: String? = nil, name: String, quantity: Double, unit: PortionUnit, nutrition: NutritionFacts) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.nutrition = nutrition
    }
}

public struct Recipe: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var ingredients: [RecipeIngredient]
    public var servings: Int
    public var createdAt: Date

    public init(id: String = UUID().uuidString, name: String, ingredients: [RecipeIngredient], servings: Int, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.servings = servings
        self.createdAt = createdAt
    }
}

public struct FixedMeal: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var items: [FoodEntry]
    public var createdAt: Date

    public init(id: String = UUID().uuidString, name: String, items: [FoodEntry], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
    }
}
