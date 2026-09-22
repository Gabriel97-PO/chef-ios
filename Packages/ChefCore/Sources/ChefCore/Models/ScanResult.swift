import Foundation

/// Base de referência dos valores nutricionais reconhecidos numa tabela.
public enum NutritionBasis: String, Codable, Sendable {
    case serving
    case per100g = "100g"
    case per100ml = "100ml"
    case unit
}

public enum FitStatus: String, Codable, Sendable {
    case fits
    case attention
    case doesNotFit = "does_not_fit"
}

public struct FoodFitResult: Codable, Sendable, Equatable {
    public var status: FitStatus
    public var calories: Double
    public var protein: Double
    public var caloriesRemaining: Double
    public var proteinRemaining: Double
    public var caloriePercentage: Int
    public var proteinPercentage: Int
    /// Resposta curta do Chef ("Pode sim.", "Pode, mas com atenção.",
    /// "Agora não seria a melhor escolha.") — pensada pra virar título/badge.
    public var title: String
    /// Explicação de uma frase do porquê, sem juízo de valor moral.
    public var message: String

    public init(
        status: FitStatus,
        calories: Double,
        protein: Double,
        caloriesRemaining: Double,
        proteinRemaining: Double,
        caloriePercentage: Int,
        proteinPercentage: Int,
        title: String,
        message: String
    ) {
        self.status = status
        self.calories = calories
        self.protein = protein
        self.caloriesRemaining = caloriesRemaining
        self.proteinRemaining = proteinRemaining
        self.caloriePercentage = caloriePercentage
        self.proteinPercentage = proteinPercentage
        self.title = title
        self.message = message
    }
}

/// Resultado bruto retornado pela camada de OCR/IA (Vision + parser), antes
/// da confirmação do usuário na tela de resultado do scanner.
public struct ScanResult: Codable, Sendable, Equatable {
    public var name: ScanField<String>?
    public var portionSize: ScanField<Double>?
    public var portionUnit: PortionUnit?
    public var nutritionBasis: NutritionBasis?
    public var calories: ScanField<Double>?
    public var protein: ScanField<Double>?
    public var carbs: ScanField<Double>?
    public var fat: ScanField<Double>?
    public var fiber: ScanField<Double>?
    public var sodium: ScanField<Double>?
    /// Nutrientes além dos seis centrais (seção 5) — açúcares, gorduras
    /// específicas, minerais, vitaminas etc. Chave ausente = nutriente não
    /// declarado na tabela; chave presente com `value: 0` = declarado como
    /// zero (seção 6) — mesma regra "nil ≠ zero" dos campos centrais.
    public var extendedNutrients: [NutrientKind: ScanField<Double>]
    /// Mensagem de inconsistência entre calorias e macros, quando detectada.
    /// Nunca corrigida silenciosamente — só sinalizada para revisão.
    public var validationWarning: String?
    public var rawText: String?
    /// Identifica o cenário de mock usado (depuração/demo do provider).
    public var mockScenario: String?

    public init(
        name: ScanField<String>? = nil,
        portionSize: ScanField<Double>? = nil,
        portionUnit: PortionUnit? = nil,
        nutritionBasis: NutritionBasis? = nil,
        calories: ScanField<Double>? = nil,
        protein: ScanField<Double>? = nil,
        carbs: ScanField<Double>? = nil,
        fat: ScanField<Double>? = nil,
        fiber: ScanField<Double>? = nil,
        sodium: ScanField<Double>? = nil,
        extendedNutrients: [NutrientKind: ScanField<Double>] = [:],
        validationWarning: String? = nil,
        rawText: String? = nil,
        mockScenario: String? = nil
    ) {
        self.name = name
        self.portionSize = portionSize
        self.portionUnit = portionUnit
        self.nutritionBasis = nutritionBasis
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.extendedNutrients = extendedNutrients
        self.sodium = sodium
        self.validationWarning = validationWarning
        self.rawText = rawText
        self.mockScenario = mockScenario
    }
}
