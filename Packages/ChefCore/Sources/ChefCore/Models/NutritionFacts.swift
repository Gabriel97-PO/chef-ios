import Foundation

/// Valores nutricionais normalizados para uma base de referência (100 g/ml
/// ou por unidade, conforme `Food.baseUnit`/`baseQuantity`).
///
/// Campos opcionais que não foram identificados/informados permanecem
/// `nil` — nunca `0`. "Não encontrado" e "zero" são estados diferentes em
/// todo o Chef (ver seção 6/9 do plano de migração).
public struct NutritionFacts: Codable, Sendable, Equatable {
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var fiber: Double?
    public var sodium: Double?

    public init(calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double? = nil, sodium: Double? = nil) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
    }

    public static let zero = NutritionFacts(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sodium: 0)
}
