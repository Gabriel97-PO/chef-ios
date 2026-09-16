import Foundation
import SwiftData
import ChefCore

/// Modelos SwiftData (seção 29 do plano de migração). O `ChefCore` continua
/// livre de dependência de SwiftData — essas classes são a camada de
/// persistência que guarda/recupera os mesmos tipos de valor do domínio
/// (`NutritionFacts`, `FoodEntry` etc, todos `Codable`), sem reescrever a
/// lógica de negócio aqui.

@Model
final class SDUserProfile {
    var name: String
    var goal: DailyGoal
    var startingWeight: Double?
    var createdAt: Date

    init(name: String, goal: DailyGoal, startingWeight: Double? = nil, createdAt: Date = Date()) {
        self.name = name
        self.goal = goal
        self.startingWeight = startingWeight
        self.createdAt = createdAt
    }
}

@Model
final class SDFood {
    @Attribute(.unique) var id: String
    var name: String
    var brand: String?
    var baseUnit: PortionUnit
    var baseQuantity: Double
    var nutrition: NutritionFacts
    var isCustom: Bool
    var source: FoodSource
    var createdAt: Date

    init(
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

    var asFood: Food {
        Food(id: id, name: name, brand: brand, baseUnit: baseUnit, baseQuantity: baseQuantity, nutrition: nutrition, isCustom: isCustom, source: source, createdAt: createdAt)
    }
}

/// Refeição registrada num dia. Os itens (`FoodEntry`, do ChefCore) ficam
/// embutidos como um array `Codable` em vez de uma relação separada — são
/// pequenos e sempre lidos/escritos junto com a refeição, então uma
/// relação SwiftData própria só adicionaria complexidade sem necessidade
/// nesta fase.
@Model
final class SDMealEntry {
    @Attribute(.unique) var id: String
    /// Chave `yyyy-MM-dd` no fuso local.
    var date: String
    var slot: MealSlot
    var items: [FoodEntry]
    var createdAt: Date

    init(id: String = UUID().uuidString, date: String, slot: MealSlot, items: [FoodEntry], createdAt: Date = Date()) {
        self.id = id
        self.date = date
        self.slot = slot
        self.items = items
        self.createdAt = createdAt
    }

    var asMealEntry: MealEntry {
        MealEntry(id: id, date: date, slot: slot, items: items, createdAt: createdAt)
    }
}

@Model
final class SDWeightEntry {
    @Attribute(.unique) var id: String
    var date: String
    var weightKg: Double

    init(id: String = UUID().uuidString, date: String, weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }

    var asWeightEntry: WeightEntry {
        WeightEntry(id: id, date: date, weightKg: weightKg)
    }
}

@Model
final class SDRecipe {
    @Attribute(.unique) var id: String
    var name: String
    var ingredients: [RecipeIngredient]
    var servings: Int
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, ingredients: [RecipeIngredient], servings: Int, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.servings = servings
        self.createdAt = createdAt
    }

    var asRecipe: Recipe {
        Recipe(id: id, name: name, ingredients: ingredients, servings: servings, createdAt: createdAt)
    }
}

@Model
final class SDFixedMeal {
    @Attribute(.unique) var id: String
    var name: String
    var items: [FoodEntry]
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, items: [FoodEntry], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
    }

    var asFixedMeal: FixedMeal {
        FixedMeal(id: id, name: name, items: items, createdAt: createdAt)
    }
}

/// Uma dieta importada e aplicada (seção 28/38 do plano de migração).
/// Versões antigas nunca são apagadas — só deixam de ser `active`.
@Model
final class SDDietVersion {
    @Attribute(.unique) var id: String
    var label: String
    var source: DietVersionSource
    var document: CnpDocument
    var active: Bool
    var importedAt: Date

    init(id: String = UUID().uuidString, label: String, source: DietVersionSource, document: CnpDocument, active: Bool, importedAt: Date = Date()) {
        self.id = id
        self.label = label
        self.source = source
        self.document = document
        self.active = active
        self.importedAt = importedAt
    }
}
