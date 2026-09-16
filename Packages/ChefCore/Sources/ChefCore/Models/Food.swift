import Foundation

public enum FoodSource: String, Codable, Sendable {
    case seed
    case manual
    case scanner
}

/// Um alimento/produto cadastrado na base local, com nutrientes por
/// `baseQuantity` unidades de `baseUnit` (ex: "por 100 g").
public struct Food: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var brand: String?
    public var baseUnit: PortionUnit
    public var baseQuantity: Double
    public var nutrition: NutritionFacts
    public var isCustom: Bool
    public var source: FoodSource
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        brand: String? = nil,
        baseUnit: PortionUnit,
        baseQuantity: Double,
        nutrition: NutritionFacts,
        isCustom: Bool,
        source: FoodSource,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.baseUnit = baseUnit
        self.baseQuantity = baseQuantity
        self.nutrition = nutrition
        self.isCustom = isCustom
        self.source = source
        self.createdAt = createdAt
    }
}

/// Um item efetivamente consumido (ou prescrito numa refeição fixa/receita),
/// já com a nutrição calculada para a quantidade indicada.
public struct FoodEntry: Identifiable, Codable, Sendable, Equatable {
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

public struct MealEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    /// Chave `yyyy-MM-dd` no fuso local — ver `DateKey`.
    public var date: String
    public var slot: MealSlot
    public var items: [FoodEntry]
    public var createdAt: Date

    public init(id: String = UUID().uuidString, date: String, slot: MealSlot, items: [FoodEntry], createdAt: Date = Date()) {
        self.id = id
        self.date = date
        self.slot = slot
        self.items = items
        self.createdAt = createdAt
    }
}
