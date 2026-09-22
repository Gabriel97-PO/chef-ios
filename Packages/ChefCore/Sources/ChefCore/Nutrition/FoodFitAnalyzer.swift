import Foundation

/// Contexto de entrada pra pergunta central do Chef: "Será que eu posso?"
/// Funciona igual pra alimento avulso, produto escaneado, receita ou
/// refeição inteira — a única coisa que muda entre eles é a `nutrition`
/// que chega já calculada pra porção escolhida (seção 13 da especificação:
/// "uma única inteligência de decisão nutricional").
public struct FoodFitInput: Sendable {
    public var nutrition: NutritionFacts
    public var dailyGoal: DailyGoal
    /// O que já foi consumido hoje, sem contar este item.
    public var consumedToday: NutritionFacts
    public var mealSlot: MealSlot?

    public init(nutrition: NutritionFacts, dailyGoal: DailyGoal, consumedToday: NutritionFacts, mealSlot: MealSlot? = nil) {
        self.nutrition = nutrition
        self.dailyGoal = dailyGoal
        self.consumedToday = consumedToday
        self.mealSlot = mealSlot
    }
}

/// **FoodFitAnalyzer** — motor único de decisão nutricional do Chef
/// (seção 13 da especificação "Será que eu posso?"). Responde sempre a
/// mesma pergunta, "cabe na sua dieta?", com o mesmo tom pros mesmos
/// dados de entrada, não importa se vieram de um alimento avulso, um
/// produto escaneado, uma receita ou uma refeição fixa.
///
/// Nunca usa linguagem moralizante ("comida ruim", "proibido", "lixo") —
/// só mede encaixe no orçamento do dia e explica o porquê (seção 3: "O
/// Chef não deve simplesmente dizer se um alimento é bom ou ruim").
/// Cálculo 100% determinístico — nenhuma IA decide o `status`, só soma e
/// compara números (seção 18: "IA não deve fazer cálculos críticos").
public enum FoodFitAnalyzer {
    private static let attentionCalorieShare = 0.35
    private static let goodProteinPerCalorie = 0.08

    public static func analyze(_ input: FoodFitInput) -> FoodFitResult {
        let food = input.nutrition
        let budget = NutritionEngine.calculateRemainingBudget(goal: input.dailyGoal, consumed: input.consumedToday)
        let caloriesRemaining = budget.caloriesRemaining
        let proteinRemaining = budget.proteinRemaining

        let caloriePercentage = input.dailyGoal.calories > 0 ? Int((food.calories / input.dailyGoal.calories * 100).rounded()) : 0
        let proteinPercentage = input.dailyGoal.protein > 0 ? Int((food.protein / input.dailyGoal.protein * 100).rounded()) : 0

        let wouldExceedCalories = food.calories > caloriesRemaining
        let shareOfRemainingCalories = caloriesRemaining > 0 ? food.calories / caloriesRemaining : .infinity
        let proteinPerCalorie = food.calories > 0 ? food.protein / food.calories : 0

        let status: FitStatus
        let title: String
        let explanation: String

        if wouldExceedCalories {
            status = .doesNotFit
            title = "Agora não seria a melhor escolha."
            let excess = NutritionEngine.round1(food.calories - caloriesRemaining)
            explanation = "Essa porção ultrapassaria em \(formatKcal(excess)) kcal o que ainda resta hoje na sua meta."
        } else if shareOfRemainingCalories > attentionCalorieShare {
            status = .attention
            title = "Pode, mas com atenção."
            let pct = Int((shareOfRemainingCalories * 100).rounded())
            explanation = "Essa porção usa \(pct)% das calorias que ainda restam hoje. Cabe, mas pesa nas próximas refeições."
        } else if proteinPerCalorie < goodProteinPerCalorie && proteinRemaining > 0 {
            status = .attention
            title = "Pode, mas com atenção."
            let pct = Int((shareOfRemainingCalories * 100).rounded())
            explanation = "Essa porção usa \(pct)% das calorias restantes e contribui pouco pra sua meta de proteína, que ainda está em aberto."
        } else {
            status = .fits
            title = "Pode sim."
            let pctCal = Int((shareOfRemainingCalories * 100).rounded())
            let pctProt = proteinRemaining > 0 ? Int((food.protein / proteinRemaining * 100).rounded()) : 100
            explanation = "Essa porção cabe tranquilamente no que você ainda tem disponível hoje — usa cerca de \(pctCal)% das calorias e \(pctProt)% da proteína restantes."
        }

        return FoodFitResult(
            status: status,
            calories: food.calories,
            protein: food.protein,
            caloriesRemaining: caloriesRemaining,
            proteinRemaining: proteinRemaining,
            caloriePercentage: caloriePercentage,
            proteinPercentage: proteinPercentage,
            title: title,
            message: explanation
        )
    }

    private static func formatKcal(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
