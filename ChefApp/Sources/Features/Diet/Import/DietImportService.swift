import Foundation
import SwiftData
import ChefCore

enum DietVersionStore {
    static func all(in context: ModelContext) -> [SDDietVersion] {
        (try? context.fetch(FetchDescriptor<SDDietVersion>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)]))) ?? []
    }

    static func active(in context: ModelContext) -> SDDietVersion? {
        all(in: context).first { $0.active }
    }
}

struct ApplyDietResult {
    var version: SDDietVersion
    var unmatchedFoods: [String]
}

/// Aplica um resultado de importação CNP (seção 36/38 do plano de migração):
/// cria uma nova versão ativa da dieta, atualiza a meta diária e cria uma
/// refeição fixa por refeição do documento. Nunca descarta um grupo de
/// substituição silenciosamente — `CNPMatching.resolvedFoods` sempre inclui
/// a primeira opção como padrão (mesma correção do bug real encontrado no
/// PWA). Alimentos sem correspondência na base local entram sem nutrição
/// calculada e voltam em `unmatchedFoods` — nunca inventamos valores.
enum DietImportService {
    static func apply(_ result: CnpImportResult, label: String, in context: ModelContext) -> ApplyDietResult {
        let document = result.document
        let localFoods = FoodStore.all(in: context)
        var unmatched = Set<String>()

        if let profile = ProfileStore.fetch(in: context) {
            profile.goal = DailyGoal(
                calories: document.goals.calories,
                protein: document.goals.proteinG,
                carbs: document.goals.carbohydratesG,
                fat: document.goals.fatG,
                fiber: document.goals.fiberG,
                water: document.goals.waterMl
            )
        }

        for meal in document.meals {
            let resolvedFoods = CNPMatching.resolvedFoods(for: meal)
            guard !resolvedFoods.isEmpty else { continue }

            let items: [FoodEntry] = resolvedFoods.map { food in
                let match = localFoods.first { normalizeText($0.name) == normalizeText(food.name) || normalizeText($0.name).contains(normalizeText(food.name)) || normalizeText(food.name).contains(normalizeText($0.name)) }
                if match == nil { unmatched.insert(food.name) }
                let nutrition = match.map { NutritionEngine.calculatePortion(food: $0.asFood, quantity: food.quantity) } ?? NutritionFacts(calories: 0, protein: 0, carbs: 0, fat: 0)
                return FoodEntry(foodId: match?.id, name: food.name, quantity: food.quantity, unit: portionUnit(for: food.unit), nutrition: nutrition)
            }
            FixedMealStore.create(name: meal.name, items: items, in: context)
        }

        for existing in DietVersionStore.all(in: context) where existing.active {
            existing.active = false
        }
        let version = SDDietVersion(label: label, source: .cnpImport, document: document, active: true)
        context.insert(version)
        try? context.save()

        return ApplyDietResult(version: version, unmatchedFoods: Array(unmatched))
    }

    /// Calcula alimentos sem correspondência sem gravar nada — usado na tela de revisão.
    static func previewUnmatchedFoods(_ document: CnpDocument, in context: ModelContext) -> [String] {
        let localFoods = FoodStore.all(in: context)
        var unmatched = Set<String>()
        for meal in document.meals {
            for food in CNPMatching.resolvedFoods(for: meal) {
                let hasMatch = localFoods.contains {
                    normalizeText($0.name) == normalizeText(food.name) || normalizeText($0.name).contains(normalizeText(food.name)) || normalizeText(food.name).contains(normalizeText($0.name))
                }
                if !hasMatch { unmatched.insert(food.name) }
            }
        }
        return Array(unmatched)
    }

    private static func portionUnit(for cnpUnit: CnpUnit) -> PortionUnit {
        switch cnpUnit {
        case .g, .kg: return .g
        case .ml, .l: return .ml
        default: return .unidade
        }
    }
}
