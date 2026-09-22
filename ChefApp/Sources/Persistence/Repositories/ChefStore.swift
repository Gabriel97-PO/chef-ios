import Foundation
import SwiftData
import ChefCore

/// Camada fina sobre o `ModelContext` do SwiftData — as Views chamam essas
/// funções em vez de montar `FetchDescriptor`/`insert` soltos por aí
/// (seção 5: "a lógica nutricional não deve ficar dentro das Views"). Os
/// cálculos em si continuam 100% no `ChefCore`; isso aqui só busca e grava.
enum ProfileStore {
    static func fetch(in context: ModelContext) -> SDUserProfile? {
        (try? context.fetch(FetchDescriptor<SDUserProfile>()))?.first
    }

    static func save(_ profile: SDUserProfile, in context: ModelContext) {
        if fetch(in: context) == nil {
            context.insert(profile)
        }
        try? context.save()
    }

    static func updateGoal(_ goal: DailyGoal, in context: ModelContext) {
        guard let profile = fetch(in: context) else { return }
        profile.goal = goal
        try? context.save()
    }
}

enum FoodStore {
    static func all(in context: ModelContext) -> [SDFood] {
        (try? context.fetch(FetchDescriptor<SDFood>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    @discardableResult
    static func create(_ food: SDFood, in context: ModelContext) -> SDFood {
        context.insert(food)
        try? context.save()
        return food
    }
}

enum MealStore {
    static func meals(on date: String, in context: ModelContext) -> [SDMealEntry] {
        let predicate = #Predicate<SDMealEntry> { $0.date == date }
        return (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
    }

    /// Junta os itens na refeição já existente daquele dia/horário, ou cria uma nova.
    static func addItems(_ items: [FoodEntry], date: String, slot: MealSlot, in context: ModelContext) {
        let slotRaw = slot
        let existing = meals(on: date, in: context).first { $0.slot == slotRaw }
        if let existing {
            existing.items.append(contentsOf: items)
        } else {
            context.insert(SDMealEntry(date: date, slot: slot, items: items))
        }
        try? context.save()
    }

    static func removeItem(mealID: String, itemID: String, in context: ModelContext) {
        let predicate = #Predicate<SDMealEntry> { $0.id == mealID }
        guard let meal = (try? context.fetch(FetchDescriptor(predicate: predicate)))?.first else { return }
        meal.items.removeAll { $0.id == itemID }
        if meal.items.isEmpty {
            context.delete(meal)
        }
        try? context.save()
    }

    static func consumedToday(date: String, in context: ModelContext) -> NutritionFacts {
        NutritionEngine.sumMeals(meals(on: date, in: context).map(\.asMealEntry))
    }
}

enum WeightStore {
    static func all(in context: ModelContext) -> [SDWeightEntry] {
        (try? context.fetch(FetchDescriptor<SDWeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    static func logToday(_ weightKg: Double, dateKey: String, in context: ModelContext) {
        let predicate = #Predicate<SDWeightEntry> { $0.date == dateKey }
        if let existing = (try? context.fetch(FetchDescriptor(predicate: predicate)))?.first {
            existing.weightKg = weightKg
        } else {
            context.insert(SDWeightEntry(date: dateKey, weightKg: weightKg))
        }
        try? context.save()
    }
}

enum RecipeStore {
    static func all(in context: ModelContext) -> [SDRecipe] {
        (try? context.fetch(FetchDescriptor<SDRecipe>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

enum FixedMealStore {
    static func all(in context: ModelContext) -> [SDFixedMeal] {
        (try? context.fetch(FetchDescriptor<SDFixedMeal>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    @discardableResult
    static func create(name: String, items: [FoodEntry], slot: MealSlot? = nil, in context: ModelContext) -> SDFixedMeal {
        let meal = SDFixedMeal(name: name, items: items, slot: slot ?? MealSlot.inferred(fromName: name))
        context.insert(meal)
        try? context.save()
        return meal
    }

    static func remove(_ meal: SDFixedMeal, in context: ModelContext) {
        context.delete(meal)
        try? context.save()
    }
}

extension RecipeStore {
    @discardableResult
    static func create(name: String, ingredients: [RecipeIngredient], servings: Int, in context: ModelContext) -> SDRecipe {
        let recipe = SDRecipe(name: name, ingredients: ingredients, servings: servings)
        context.insert(recipe)
        try? context.save()
        return recipe
    }

    static func remove(_ recipe: SDRecipe, in context: ModelContext) {
        context.delete(recipe)
        try? context.save()
    }
}

/// Lista de compras (seção 21): lista persistente e independente, que o
/// usuário edita à mão ou "puxa" da dieta atual — puxar nunca duplica
/// linha, soma na existente quando o alimento/unidade já está na lista.
enum ShoppingListStore {
    static func all(in context: ModelContext) -> [SDShoppingListItem] {
        (try? context.fetch(FetchDescriptor<SDShoppingListItem>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    @discardableResult
    static func add(name: String, quantity: Double, unit: PortionUnit, in context: ModelContext) -> SDShoppingListItem {
        let item = SDShoppingListItem(name: name, quantity: quantity, unit: unit)
        context.insert(item)
        try? context.save()
        return item
    }

    static func toggle(_ item: SDShoppingListItem, in context: ModelContext) {
        item.checked.toggle()
        try? context.save()
    }

    static func remove(_ item: SDShoppingListItem, in context: ModelContext) {
        context.delete(item)
        try? context.save()
    }

    static func clearChecked(in context: ModelContext) {
        for item in all(in: context) where item.checked {
            context.delete(item)
        }
        try? context.save()
    }

    /// Junta os ingredientes das refeições fixas e receitas cadastradas à
    /// lista — soma na entrada existente (mesmo nome normalizado + mesma
    /// unidade, ainda não marcada como comprada) em vez de duplicar.
    static func mergeFromDiet(fixedMeals: [SDFixedMeal], recipes: [SDRecipe], in context: ModelContext) {
        let entries = ShoppingListBuilder.aggregate(
            ShoppingListBuilder.fromFixedMeals(fixedMeals.map(\.asFixedMeal)).map { ($0.name, $0.quantity, $0.unit) } +
            ShoppingListBuilder.fromRecipes(recipes.map(\.asRecipe)).map { ($0.name, $0.quantity, $0.unit) }
        )

        let existing = all(in: context).filter { !$0.checked }
        for entry in entries {
            if let match = existing.first(where: { normalizeText($0.name) == normalizeText(entry.name) && $0.unit == entry.unit }) {
                match.quantity += entry.quantity
            } else {
                context.insert(SDShoppingListItem(name: entry.name, quantity: entry.quantity, unit: entry.unit))
            }
        }
        try? context.save()
    }
}
