import Foundation

/// Chef Nutrition Protocol (CNP) v1 — formato pensado para que softwares de
/// nutrição exportem dietas que o Chef consiga importar sem que o
/// nutricionista precise entender tecnologia (o JSON é o formato interno,
/// não algo que a pessoa escreve à mão).

public struct CnpGoals: Codable, Sendable, Equatable {
    public var calories: Double
    public var proteinG: Double
    public var carbohydratesG: Double?
    public var fatG: Double?
    public var fiberG: Double?
    public var waterMl: Double?

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbohydratesG = "carbohydrates_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case waterMl = "water_ml"
    }

    public init(calories: Double, proteinG: Double, carbohydratesG: Double? = nil, fatG: Double? = nil, fiberG: Double? = nil, waterMl: Double? = nil) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbohydratesG = carbohydratesG
        self.fatG = fatG
        self.fiberG = fiberG
        self.waterMl = waterMl
    }
}

/// Unidades aceitas em um item de alimento do CNP (seção 25 do plano de
/// migração) — mais amplo que `PortionUnit`, que é a unidade interna do
/// Chef; a normalização de uma pra outra acontece no parser/matching.
public enum CnpUnit: String, Codable, Sendable {
    case g, kg, ml, l, unit, slice, tablespoon, teaspoon, cup, glass, portion
}

public struct CnpFoodItem: Codable, Sendable, Equatable {
    public var name: String
    public var quantity: Double
    public var unit: CnpUnit

    public init(name: String, quantity: Double, unit: CnpUnit) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}

/// Grupo de substituição: "arroz OU batata OU mandioca".
public struct CnpSubstitutionGroup: Codable, Sendable, Equatable {
    public var group: String
    public var options: [CnpFoodItem]

    public init(group: String, options: [CnpFoodItem]) {
        self.group = group
        self.options = options
    }
}

/// Refeições alternativas completas: "opção 1 OU opção 2".
public struct CnpAlternativeMeal: Codable, Sendable, Equatable {
    public var label: String
    public var foods: [CnpFoodItem]

    public init(label: String, foods: [CnpFoodItem]) {
        self.label = label
        self.foods = foods
    }
}

public struct CnpMeal: Codable, Sendable, Equatable {
    public var name: String
    public var time: String?
    public var foods: [CnpFoodItem]
    public var substitutions: [CnpSubstitutionGroup]?
    public var alternatives: [CnpAlternativeMeal]?
    public var notes: String?

    public init(name: String, time: String? = nil, foods: [CnpFoodItem], substitutions: [CnpSubstitutionGroup]? = nil, alternatives: [CnpAlternativeMeal]? = nil, notes: String? = nil) {
        self.name = name
        self.time = time
        self.foods = foods
        self.substitutions = substitutions
        self.alternatives = alternatives
        self.notes = notes
    }
}

public struct CnpPatient: Codable, Sendable, Equatable {
    public var name: String
    public init(name: String) { self.name = name }
}

public struct CnpDocument: Codable, Sendable, Equatable {
    public var `protocol`: String
    public var version: String
    public var patient: CnpPatient
    public var goals: CnpGoals
    public var meals: [CnpMeal]
    public var observations: String?

    public init(protocol: String = "chef-nutrition", version: String = "1.0", patient: CnpPatient, goals: CnpGoals, meals: [CnpMeal], observations: String? = nil) {
        self.protocol = `protocol`
        self.version = version
        self.patient = patient
        self.goals = goals
        self.meals = meals
        self.observations = observations
    }
}

/// Resultado da importação: nunca aplica a dieta silenciosamente. Campos
/// não encontrados ficam ausentes/zerados de forma explícita — nunca
/// inventados (seção 27/37 do plano de migração).
public struct CnpImportSummary: Sendable, Equatable {
    public var foundCalorieGoal: Bool
    public var foundProteinGoal: Bool
    public var mealCount: Int
    public var foodCount: Int
    public var substitutionCount: Int
    public var ambiguities: [String]

    public init(foundCalorieGoal: Bool, foundProteinGoal: Bool, mealCount: Int, foodCount: Int, substitutionCount: Int, ambiguities: [String]) {
        self.foundCalorieGoal = foundCalorieGoal
        self.foundProteinGoal = foundProteinGoal
        self.mealCount = mealCount
        self.foodCount = foodCount
        self.substitutionCount = substitutionCount
        self.ambiguities = ambiguities
    }
}

public struct CnpImportResult: Sendable, Equatable {
    public var document: CnpDocument
    public var summary: CnpImportSummary
    public var sourceText: String

    public init(document: CnpDocument, summary: CnpImportSummary, sourceText: String) {
        self.document = document
        self.summary = summary
        self.sourceText = sourceText
    }
}

/// Uma dieta importada e aplicada. Versões antigas nunca são apagadas ao
/// importar uma nova — apenas deixam de ser `active` (seção 28).
public struct DietVersion: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var label: String
    public var source: DietVersionSource
    public var document: CnpDocument
    public var active: Bool
    public var importedAt: Date

    public init(id: String = UUID().uuidString, label: String, source: DietVersionSource, document: CnpDocument, active: Bool, importedAt: Date = Date()) {
        self.id = id
        self.label = label
        self.source = source
        self.document = document
        self.active = active
        self.importedAt = importedAt
    }
}

public enum DietVersionSource: String, Codable, Sendable {
    case manual
    case cnpImport = "cnp_import"
}
