import Foundation

/// Sexo biológico — usado só como variável das fórmulas de metabolismo
/// basal, que são calibradas em cima dele. `unspecified` usa a média das
/// duas constantes em vez de chutar uma, pra não inventar um número.
public enum BiologicalSex: String, Codable, Sendable, CaseIterable, Identifiable {
    case male, female, unspecified

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .male: return "Masculino"
        case .female: return "Feminino"
        case .unspecified: return "Prefiro não informar"
        }
    }
}

/// Nível de atividade física, o multiplicador que transforma metabolismo
/// basal (TMB) em gasto energético total (GET).
public enum ActivityLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive

    public var id: String { rawValue }

    public var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    public var label: String {
        switch self {
        case .sedentary: return "Sedentário"
        case .light: return "Leve"
        case .moderate: return "Moderado"
        case .active: return "Ativo"
        case .veryActive: return "Muito ativo"
        }
    }

    public var detail: String {
        switch self {
        case .sedentary: return "Trabalho sentado, sem exercício"
        case .light: return "Exercício leve 1–3x por semana"
        case .moderate: return "Exercício moderado 3–5x por semana"
        case .active: return "Exercício intenso 6–7x por semana"
        case .veryActive: return "Trabalho físico ou treino 2x ao dia"
        }
    }
}

/// O que a pessoa quer fazer com o peso — define o déficit/superávit
/// aplicado sobre o gasto energético total.
public enum WeightObjective: String, Codable, Sendable, CaseIterable, Identifiable {
    case lose, maintain, gain

    public var id: String { rawValue }

    /// Ajuste percentual sobre o GET. Déficit de 20% e superávit de 10% são
    /// as faixas usadas na prática por serem sustentáveis; déficits maiores
    /// derrubam massa magra junto.
    public var energyAdjustment: Double {
        switch self {
        case .lose: return -0.20
        case .maintain: return 0
        case .gain: return 0.10
        }
    }

    /// Proteína em gramas por kg de peso corporal.
    public var proteinPerKg: Double {
        switch self {
        case .lose: return 1.8      // preserva massa magra durante o déficit
        case .maintain: return 1.6
        case .gain: return 1.8
        }
    }

    public var label: String {
        switch self {
        case .lose: return "Perder peso"
        case .maintain: return "Manter peso"
        case .gain: return "Ganhar peso"
        }
    }
}

/// Medidas corporais necessárias pro cálculo. Tudo opcional exceto peso,
/// altura e idade — sem esses três não existe estimativa de TMB, e o motor
/// devolve `nil` em vez de preencher com um valor inventado.
public struct BodyMetrics: Codable, Sendable, Equatable {
    public var weightKg: Double
    public var heightCm: Double
    public var age: Int
    public var sex: BiologicalSex
    public var activity: ActivityLevel
    public var objective: WeightObjective

    public init(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex = .unspecified,
        activity: ActivityLevel = .sedentary,
        objective: WeightObjective = .maintain
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.sex = sex
        self.activity = activity
        self.objective = objective
    }

    public var isComplete: Bool {
        weightKg > 0 && heightCm > 0 && age > 0
    }
}

/// Metas calculadas a partir do metabolismo basal.
public struct EnergyTargets: Sendable, Equatable {
    /// Taxa metabólica basal (kcal/dia em repouso absoluto).
    public var basalMetabolicRate: Double
    /// Gasto energético total = TMB × fator de atividade.
    public var totalEnergyExpenditure: Double
    /// Meta calórica = GET + ajuste do objetivo.
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var fiber: Double
    /// Água em ml.
    public var water: Double

    public var asDailyGoal: DailyGoal {
        DailyGoal(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            water: water
        )
    }
}

/// Converte medidas corporais em metas diárias (roadmap itens 6 e 8).
///
/// Todos os números aqui são **estimativas populacionais**, não prescrição:
/// a UI sempre mostra isso como sugestão editável, e uma dieta prescrita
/// por profissional (importada via CNP) tem precedência sobre o cálculo —
/// mesma regra do resto do app de nunca sobrescrever dado real com
/// estimativa.
public enum EnergyEngine {
    /// Mifflin-St Jeor (1990), a fórmula preditiva de TMB com menor erro
    /// médio em população adulta — melhor que Harris-Benedict, que
    /// superestima em pessoas com sobrepeso.
    public static func basalMetabolicRate(for metrics: BodyMetrics) -> Double? {
        guard metrics.isComplete else { return nil }

        let base = 10 * metrics.weightKg
            + 6.25 * metrics.heightCm
            - 5 * Double(metrics.age)

        let sexConstant: Double
        switch metrics.sex {
        case .male: sexConstant = 5
        case .female: sexConstant = -161
        // Média das duas constantes: sem o dado, fica no meio em vez de
        // assumir um dos dois.
        case .unspecified: sexConstant = -78
        }

        return round1(base + sexConstant)
    }

    public static func calculateTargets(for metrics: BodyMetrics) -> EnergyTargets? {
        guard let bmr = basalMetabolicRate(for: metrics) else { return nil }

        let tee = bmr * metrics.activity.factor
        let calories = tee * (1 + metrics.objective.energyAdjustment)

        // Proteína por kg de peso, conforme o objetivo.
        let protein = metrics.weightKg * metrics.objective.proteinPerKg

        // Gordura em 27,5% das calorias (meio da faixa de 25–30% mais
        // usada), a 9 kcal/g.
        let fat = calories * 0.275 / 9

        // Carboidrato é o que sobra depois de proteína e gordura, a 4 kcal/g.
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4)

        // Fibra: 14 g por 1000 kcal (recomendação de referência do
        // Institute of Medicine).
        let fiber = calories / 1000 * 14

        // Água: 35 ml por kg de peso, a regra prática mais citada.
        let water = metrics.weightKg * 35

        return EnergyTargets(
            basalMetabolicRate: bmr,
            totalEnergyExpenditure: round1(tee),
            calories: (calories / 10).rounded() * 10,
            protein: protein.rounded(),
            carbs: carbs.rounded(),
            fat: fat.rounded(),
            fiber: fiber.rounded(),
            water: (water / 100).rounded() * 100
        )
    }

    private static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}
