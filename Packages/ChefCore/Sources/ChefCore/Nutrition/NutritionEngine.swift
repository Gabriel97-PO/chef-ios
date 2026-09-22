import Foundation

/// NutritionEngine: única fonte de verdade para cálculos nutricionais do
/// Chef. Nenhuma regra de negócio nutricional deve viver em Views — tudo
/// passa por aqui para manter a lógica testável e consistente (mesma regra
/// que valia no PWA, agora em Swift puro, testável via `swift test`).
public enum NutritionEngine {

    /// Arredonda para 1 casa decimal, evitando "sujeira" de ponto flutuante.
    static func round1(_ n: Double) -> Double {
        (n * 10).rounded() / 10
    }

    private static func scale(_ facts: NutritionFacts, by factor: Double) -> NutritionFacts {
        NutritionFacts(
            calories: round1(facts.calories * factor),
            protein: round1(facts.protein * factor),
            carbs: round1(facts.carbs * factor),
            fat: round1(facts.fat * factor),
            fiber: facts.fiber.map { round1($0 * factor) },
            sodium: facts.sodium.map { round1($0 * factor) }
        )
    }

    /// Calcula os nutrientes de uma quantidade consumida a partir dos
    /// valores base do alimento (ex: alimento cadastrado "por 100g",
    /// quantidade consumida 60g → 60% dos valores base).
    public static func calculatePortion(food: Food, quantity: Double) -> NutritionFacts {
        let factor = food.baseQuantity > 0 ? quantity / food.baseQuantity : 0
        return scale(food.nutrition, by: factor)
    }

    /// Soma os nutrientes de uma lista de itens (refeições, ingredientes de receita etc.).
    public static func sumNutrition(_ items: [NutritionFacts]) -> NutritionFacts {
        items.reduce(NutritionFacts.zero) { acc, item in
            NutritionFacts(
                calories: round1(acc.calories + item.calories),
                protein: round1(acc.protein + item.protein),
                carbs: round1(acc.carbs + item.carbs),
                fat: round1(acc.fat + item.fat),
                fiber: round1((acc.fiber ?? 0) + (item.fiber ?? 0)),
                sodium: round1((acc.sodium ?? 0) + (item.sodium ?? 0))
            )
        }
    }

    public static func sumMeals(_ meals: [MealEntry]) -> NutritionFacts {
        sumNutrition(meals.flatMap { $0.items.map(\.nutrition) })
    }

    public static func calculateRecipeTotal(_ recipe: Recipe) -> NutritionFacts {
        sumNutrition(recipe.ingredients.map(\.nutrition))
    }

    /// Nutrientes de uma única porção da receita (total dividido pelas porções).
    public static func calculateRecipePerServing(_ recipe: Recipe) -> NutritionFacts {
        let total = calculateRecipeTotal(recipe)
        let servings = recipe.servings > 0 ? Double(recipe.servings) : 1
        return scale(total, by: 1 / servings)
    }

    public struct RemainingBudget: Equatable, Sendable {
        public var caloriesConsumed: Double
        public var proteinConsumed: Double
        public var caloriesRemaining: Double
        public var proteinRemaining: Double
        public var caloriePercentageUsed: Int
        public var proteinPercentageUsed: Int
    }

    /// Calcula o orçamento restante do dia com base na meta e no que já foi consumido.
    public static func calculateRemainingBudget(goal: DailyGoal, consumed: NutritionFacts) -> RemainingBudget {
        let caloriesRemaining = round1(goal.calories - consumed.calories)
        let proteinRemaining = round1(goal.protein - consumed.protein)
        let caloriePct = goal.calories > 0 ? Int((consumed.calories / goal.calories * 100).rounded()) : 0
        let proteinPct = goal.protein > 0 ? Int((consumed.protein / goal.protein * 100).rounded()) : 0
        return RemainingBudget(
            caloriesConsumed: consumed.calories,
            proteinConsumed: consumed.protein,
            caloriesRemaining: caloriesRemaining,
            proteinRemaining: proteinRemaining,
            caloriePercentageUsed: caloriePct,
            proteinPercentageUsed: proteinPct
        )
    }

    public struct DayTotals: Equatable, Sendable {
        public var date: String
        public var consumed: NutritionFacts
        public var goal: DailyGoal
        public var budget: RemainingBudget
    }

    public static func buildDayTotals(date: String, meals: [MealEntry], goal: DailyGoal) -> DayTotals {
        let consumed = sumMeals(meals)
        return DayTotals(date: date, consumed: consumed, goal: goal, budget: calculateRemainingBudget(goal: goal, consumed: consumed))
    }

    /// Média móvel simples de peso considerando até os últimos N registros
    /// (padrão: 7 dias). Nunca usa um único dia isolado para tendência.
    public static func calculateWeightAverage(_ entries: [WeightEntry], windowSize: Int = 7) -> Double? {
        guard !entries.isEmpty else { return nil }
        let sorted = entries.sorted { $0.date > $1.date }
        let window = Array(sorted.prefix(windowSize))
        let sum = window.reduce(0) { $0 + $1.weightKg }
        return (sum / Double(window.count) * 100).rounded() / 100
    }

    public static func calculateWeightChange(_ entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2 else { return nil }
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return round1(last.weightKg - first.weightKg)
    }

    /// Verifica coerência energética entre calorias declaradas e macros:
    /// 4 kcal/g proteína, 4 kcal/g carboidrato, 9 kcal/g gordura. Nunca
    /// corrige o valor — apenas sinaliza para o usuário revisar a tabela.
    public static func validateNutritionCoherence(_ facts: NutritionFacts) -> String? {
        guard facts.calories > 0 else { return nil }
        let expected = facts.protein * 4 + facts.carbs * 4 + facts.fat * 9
        let tolerance = max(30, facts.calories * 0.2)
        if abs(expected - facts.calories) > tolerance {
            return "Alguns valores parecem inconsistentes entre si. Revise a tabela antes de adicionar."
        }
        return nil
    }

    public struct SuggestionItem: Identifiable, Equatable, Sendable {
        public enum Kind: Sendable { case recipe, fixedMeal }
        public var id: String
        public var name: String
        public var kind: Kind
        public var nutrition: NutritionFacts
    }

    /// Sugere receitas/refeições fixas já cadastradas que cabem no
    /// orçamento restante do dia, priorizando maior densidade de proteína
    /// por caloria. Não é recomendação nutricional, só um atalho para o que
    /// o usuário já cadastrou e que se encaixa agora.
    public static func getSuggestions(recipes: [Recipe], fixedMeals: [FixedMeal], remaining: RemainingBudget, limit: Int = 3) -> [SuggestionItem] {
        var candidates: [SuggestionItem] = recipes.map {
            SuggestionItem(id: $0.id, name: $0.name, kind: .recipe, nutrition: calculateRecipePerServing($0))
        }
        candidates += fixedMeals.map {
            SuggestionItem(id: $0.id, name: $0.name, kind: .fixedMeal, nutrition: sumNutrition($0.items.map(\.nutrition)))
        }

        return candidates
            .filter { $0.nutrition.calories > 0 && $0.nutrition.calories <= remaining.caloriesRemaining }
            .sorted { ($0.nutrition.protein / $0.nutrition.calories) > ($1.nutrition.protein / $1.nutrition.calories) }
            .prefix(limit)
            .map { $0 }
    }

    /// Frase curta e neutra sobre o espaço restante no orçamento do dia.
    public static func budgetHint(_ remaining: RemainingBudget) -> String {
        if remaining.caloriesRemaining <= 0 {
            return "Você já utilizou toda a meta de calorias de hoje."
        }
        if remaining.proteinRemaining > 25 && remaining.caloriesRemaining > 400 {
            return "Você ainda tem bastante espaço para uma refeição rica em proteína."
        }
        if remaining.caloriesRemaining < 250 {
            return "Pouco espaço calórico restante hoje — prefira porções menores."
        }
        return "Você ainda tem espaço no seu orçamento de hoje."
    }
}
