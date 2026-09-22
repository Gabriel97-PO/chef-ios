import Foundation

/// Taxonomia completa de nutrientes que podem aparecer numa tabela
/// nutricional (seção 5 da especificação "Será que eu posso?") — além dos
/// seis campos centrais já em `NutritionFacts` (calorias, proteína,
/// carboidratos, gordura, fibra, sódio), que continuam intocados pra não
/// quebrar todo o resto do app que já depende deles pra soma/orçamento.
///
/// `NutrientKind` é só a CHAVE — o valor de cada um vive num
/// `ScanResult.extendedNutrients: [NutrientKind: ScanField<Double>]`
/// (ver `ScanResult.swift`), reaproveitando o mesmo par valor+confiança já
/// usado nos seis campos centrais, em vez de inventar um modelo de
/// confiança paralelo. Ausência da chave no dicionário = não declarado;
/// chave presente com valor 0 = declarado como zero (seção 6) — a mesma
/// regra "nil ≠ zero" que já vale pros campos centrais, só que agora
/// modelada por "está ou não está no dicionário" em vez de opcional solto.
///
/// A lista cobre a especificação inteira, mas o parser (`NutritionLabelParser`)
/// só preenche de fato o que aparece com regularidade em rótulos brasileiros
/// reais — o resto existe pra a estrutura não precisar mudar quando o
/// parser aprender a ler mais campos (extensível sem alterar o modelo
/// principal, como pedido na seção 5).
public enum NutrientKind: String, Codable, Sendable, CaseIterable, Hashable {
    // MARK: Energia
    case energyKj

    // MARK: Carboidratos
    case totalSugars
    case addedSugars
    case glucose
    case fructose
    case galactose
    case sucrose
    case lactose
    case maltose
    case polyols

    // MARK: Gorduras
    case saturatedFat
    case transFat
    case monounsaturatedFat
    case polyunsaturatedFat
    case omega3
    case omega6
    case omega9
    case oleicAcid
    case linoleicAcid
    case linolenicAcid
    case epa
    case dha
    case cholesterol

    // MARK: Minerais
    case calcium
    case iron
    case potassium
    case magnesium
    case phosphorus
    case zinc
    case copper
    case manganese
    case iodine
    case selenium
    case chromium
    case molybdenum
    case chloride
    case fluoride

    // MARK: Vitaminas
    case vitaminA
    case vitaminD
    case vitaminE
    case vitaminK
    case vitaminC
    case vitaminB1
    case vitaminB2
    case vitaminB3
    case vitaminB5
    case vitaminB6
    case vitaminB7
    case vitaminB9
    case vitaminB12

    // MARK: Outros
    case choline
    case taurine

    /// Rótulo em português, pra exibição direta na UI.
    public var label: String {
        switch self {
        case .energyKj: return "Valor energético (kJ)"
        case .totalSugars: return "Açúcares totais"
        case .addedSugars: return "Açúcares adicionados"
        case .glucose: return "Glicose"
        case .fructose: return "Frutose"
        case .galactose: return "Galactose"
        case .sucrose: return "Sacarose"
        case .lactose: return "Lactose"
        case .maltose: return "Maltose"
        case .polyols: return "Polióis"
        case .saturatedFat: return "Gorduras saturadas"
        case .transFat: return "Gorduras trans"
        case .monounsaturatedFat: return "Gorduras monoinsaturadas"
        case .polyunsaturatedFat: return "Gorduras poli-insaturadas"
        case .omega3: return "Ômega 3"
        case .omega6: return "Ômega 6"
        case .omega9: return "Ômega 9"
        case .oleicAcid: return "Ácido oleico"
        case .linoleicAcid: return "Ácido linoleico"
        case .linolenicAcid: return "Ácido linolênico"
        case .epa: return "EPA"
        case .dha: return "DHA"
        case .cholesterol: return "Colesterol"
        case .calcium: return "Cálcio"
        case .iron: return "Ferro"
        case .potassium: return "Potássio"
        case .magnesium: return "Magnésio"
        case .phosphorus: return "Fósforo"
        case .zinc: return "Zinco"
        case .copper: return "Cobre"
        case .manganese: return "Manganês"
        case .iodine: return "Iodo"
        case .selenium: return "Selênio"
        case .chromium: return "Cromo"
        case .molybdenum: return "Molibdênio"
        case .chloride: return "Cloro"
        case .fluoride: return "Flúor"
        case .vitaminA: return "Vitamina A"
        case .vitaminD: return "Vitamina D"
        case .vitaminE: return "Vitamina E"
        case .vitaminK: return "Vitamina K"
        case .vitaminC: return "Vitamina C"
        case .vitaminB1: return "Vitamina B1"
        case .vitaminB2: return "Vitamina B2"
        case .vitaminB3: return "Vitamina B3"
        case .vitaminB5: return "Vitamina B5"
        case .vitaminB6: return "Vitamina B6"
        case .vitaminB7: return "Vitamina B7"
        case .vitaminB9: return "Vitamina B9"
        case .vitaminB12: return "Vitamina B12"
        case .choline: return "Colina"
        case .taurine: return "Taurina"
        }
    }

    /// Unidade de referência mais comum em rótulos brasileiros.
    public var referenceUnit: String {
        switch self {
        case .energyKj: return "kJ"
        case .vitaminA, .vitaminD, .vitaminB12, .vitaminB9, .vitaminB7, .iodine, .selenium, .chromium, .molybdenum:
            return "µg"
        default:
            return "g"
        }
    }
}
