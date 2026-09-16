import Foundation

/// Unidade de porção de um alimento ou item consumido.
public enum PortionUnit: String, Codable, Sendable, CaseIterable {
    case g
    case ml
    case unidade
}

/// Uma das seis refeições do dia (seção 5 do briefing original do PWA).
public enum MealSlot: String, Codable, Sendable, CaseIterable, Identifiable {
    case cafeDaManha = "cafe_da_manha"
    case almoco
    case lanche
    case posTreino = "pos_treino"
    case jantar
    case outro

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .cafeDaManha: return "Café da manhã"
        case .almoco: return "Almoço"
        case .lanche: return "Lanche"
        case .posTreino: return "Pós-treino"
        case .jantar: return "Jantar"
        case .outro: return "Outro"
        }
    }

    /// Horário de referência para ordenar/priorizar a "próxima refeição" no dashboard.
    public var defaultHour: Int {
        switch self {
        case .cafeDaManha: return 7
        case .almoco: return 12
        case .lanche: return 15
        case .posTreino: return 18
        case .jantar: return 20
        case .outro: return 21
        }
    }
}
