import Foundation
import SwiftData
import ChefCore

/// Dados de demonstração (seção 35 do plano de migração) — populados só na
/// primeira execução, isolados do resto do app como o próprio documento
/// pede ("esses dados são apenas seed/demo e devem ficar separados dos
/// modelos de produção" — aqui não há um modelo de produção paralelo
/// ainda, mas o seed nunca roda de novo sobre um banco já existente).
enum SeedDataService {
    static func seedIfNeeded(context: ModelContext) {
        if ProfileStore.fetch(in: context) == nil {
            let profile = SDUserProfile(
                name: "Gabriel",
                goal: DailyGoal(calories: 2100, protein: 170, carbs: 210, fat: 70, fiber: 30, water: 3000),
                startingWeight: 120
            )
            ProfileStore.save(profile, in: context)
        }

        if FoodStore.all(in: context).isEmpty {
            for food in makeSeedFoods() {
                FoodStore.create(food, in: context)
            }
        }

        if RecipeStore.all(in: context).isEmpty {
            for recipe in seedRecipes(context: context) {
                context.insert(recipe)
            }
            try? context.save()
        }

        // Horários de refeição de 3 em 3 horas (roadmap item 10). Os
        // lembretes já nascem desligados: notificação é coisa que o usuário
        // liga, não que o app impõe.
        if (try? context.fetch(FetchDescriptor<SDMealTime>()))?.isEmpty ?? true {
            let schedule: [(MealSlot, Int)] = [
                (.cafeDaManha, 7),
                (.lanche, 10),
                (.almoco, 13),
                (.posTreino, 16),
                (.jantar, 19),
                (.outro, 22),
            ]
            for (slot, hour) in schedule {
                context.insert(SDMealTime(slot: slot, hour: hour, reminderEnabled: false))
            }
            try? context.save()
        }

        if WeightStore.all(in: context).isEmpty {
            let sequence: [Double] = [120.8, 120.4, 120.7, 120.1, 119.9, 120.2, 119.8]
            let calendar = Calendar.current
            for (offset, weight) in sequence.enumerated() {
                let daysAgo = sequence.count - 1 - offset
                guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
                context.insert(SDWeightEntry(date: DateKey.string(from: date), weightKg: weight))
            }
            try? context.save()
        }
    }

    private static func food(_ id: String, _ name: String, _ unit: PortionUnit, _ qty: Double, _ facts: NutritionFacts) -> SDFood {
        SDFood(id: id, name: name, baseUnit: unit, baseQuantity: qty, nutrition: facts, isCustom: false, source: .seed)
    }

    private static func makeSeedFoods() -> [SDFood] {
        [
        food("food-arroz-branco", "Arroz branco cozido", .g, 100, NutritionFacts(calories: 128, protein: 2.5, carbs: 28, fat: 0.2, fiber: 0.4, sodium: 1)),
        food("food-peito-frango", "Peito de frango grelhado", .g, 100, NutritionFacts(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, sodium: 74)),
        food("food-carne-moida", "Carne moída (patinho)", .g, 100, NutritionFacts(calories: 217, protein: 26, carbs: 0, fat: 12, fiber: 0, sodium: 66)),
        food("food-brocolis", "Brócolis cozido", .g, 100, NutritionFacts(calories: 35, protein: 2.4, carbs: 7, fat: 0.4, fiber: 3.3, sodium: 33)),
        food("food-couve-flor", "Couve-flor cozida", .g, 100, NutritionFacts(calories: 25, protein: 1.9, carbs: 5, fat: 0.3, fiber: 2, sodium: 15)),
        food("food-ovo", "Ovo cozido", .unidade, 1, NutritionFacts(calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3, fiber: 0, sodium: 62)),
        food("food-whey", "Whey protein (pó)", .g, 100, NutritionFacts(calories: 400, protein: 80, carbs: 8, fat: 6, fiber: 1, sodium: 200)),
        food("food-leite-desnatado", "Leite desnatado", .ml, 100, NutritionFacts(calories: 35, protein: 3.4, carbs: 5, fat: 0.2, fiber: 0, sodium: 50)),
        food("food-banana", "Banana", .g, 100, NutritionFacts(calories: 89, protein: 1.1, carbs: 23, fat: 0.3, fiber: 2.6, sodium: 1)),
        food("food-rap10", "Rap10", .g, 100, NutritionFacts(calories: 300, protein: 8, carbs: 45, fat: 9, fiber: 3, sodium: 480)),
        food("food-ricota", "Ricota", .g, 100, NutritionFacts(calories: 138, protein: 11, carbs: 3, fat: 10, fiber: 0, sodium: 84)),
        food("food-pao-frances", "Pão francês", .unidade, 1, NutritionFacts(calories: 150, protein: 4, carbs: 29, fat: 1.5, fiber: 1.2, sodium: 290)),
        food("food-salame", "Salame", .g, 100, NutritionFacts(calories: 407, protein: 22, carbs: 2, fat: 35, fiber: 0, sodium: 1890)),
        food("food-parmesao", "Parmesão", .g, 100, NutritionFacts(calories: 392, protein: 35, carbs: 3.2, fat: 26, fiber: 0, sodium: 1529)),
        food("food-azeite", "Azeite de oliva", .ml, 100, NutritionFacts(calories: 884, protein: 0, carbs: 0, fat: 100, fiber: 0, sodium: 2)),
        food("food-goma-tapioca", "Goma de tapioca hidratada", .g, 100, NutritionFacts(calories: 180, protein: 0.2, carbs: 44, fat: 0.1, fiber: 0.5, sodium: 5)),
        ]
    }

    private static func seedRecipes(context: ModelContext) -> [SDRecipe] {
        let foodsByID = Dictionary(uniqueKeysWithValues: makeSeedFoods().map { ($0.id, $0) })

        func ingredient(_ foodID: String, _ quantity: Double, _ unit: PortionUnit, label: String? = nil) -> RecipeIngredient {
            guard let food = foodsByID[foodID] else { fatalError("Seed: alimento \(foodID) não encontrado") }
            return RecipeIngredient(
                foodId: foodID,
                name: label ?? food.name,
                quantity: quantity,
                unit: unit,
                nutrition: NutritionEngine.calculatePortion(food: food.asFood, quantity: quantity)
            )
        }

        return [
            SDRecipe(
                id: "recipe-frango-brocolis-airfryer",
                name: "Frango + brócolis na Air Fryer",
                ingredients: [
                    ingredient("food-peito-frango", 200, .g),
                    ingredient("food-brocolis", 150, .g),
                    ingredient("food-azeite", 5, .ml),
                    ingredient("food-parmesao", 15, .g),
                ],
                servings: 2
            ),
            SDRecipe(
                id: "recipe-rap10-frango",
                name: "Rap10 de frango",
                ingredients: [
                    ingredient("food-rap10", 90, .g, label: "2 Rap10 (90 g)"),
                    ingredient("food-peito-frango", 150, .g),
                    ingredient("food-ricota", 50, .g),
                ],
                servings: 1
            ),
            SDRecipe(
                id: "recipe-crepioca",
                name: "Crepioca",
                ingredients: [
                    ingredient("food-ovo", 2, .unidade, label: "2 ovos"),
                    ingredient("food-goma-tapioca", 30, .g),
                    ingredient("food-ricota", 15, .g),
                ],
                servings: 1
            ),
            SDRecipe(
                id: "recipe-whey-leite-banana",
                name: "Whey + leite + banana",
                ingredients: [
                    ingredient("food-whey", 30, .g),
                    ingredient("food-leite-desnatado", 200, .ml),
                    ingredient("food-banana", 100, .g),
                ],
                servings: 1
            ),
        ]
    }
}

/// Chave `yyyy-MM-dd` no fuso local — mesma convenção do PWA, evita o bug
/// clássico de `toISOString()`/UTC virar o dia errado perto da meia-noite.
enum DateKey {
    static func string(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static func today() -> String { string(from: Date()) }

    static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.date(from: key)
    }
}
