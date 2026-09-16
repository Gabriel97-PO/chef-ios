import Foundation

/// Interpreta as linhas de texto que o OCR (Vision) reconheceu numa foto de
/// tabela nutricional brasileira e monta um `ScanResult`.
///
/// OCR NÃO é interpretação (seção 14 do plano de migração): o Vision só
/// responde "o que está escrito". Este parser responde "o que isso
/// significa nutricionalmente" — é lógica pura, sem depender do Vision
/// framework, então é testável com `swift test` usando linhas sintéticas,
/// sem precisar de câmera nem simulador.
///
/// Limitação conhecida: tabelas de duas colunas onde os rótulos e os
/// números aparecem em blocos separados (o OCR lê a imagem da esquerda pra
/// direita, então "120\n22\n3" pode vir antes de "Valor energético\n
/// Carboidratos\nProteínas") são tratadas com um fallback por ordem de
/// aparição — funciona na maioria dos rótulos reais, mas reconstrução de
/// layout por posição geométrica (bounding boxes) é um refinamento futuro.
public enum NutritionLabelParser {

    private struct FieldMatch {
        var value: Double
        var confidence: Double
    }

    private static let numberPattern = try! NSRegularExpression(pattern: #"(\d+[.,]?\d*)"#)

    private static let keywordPatterns: [(keyword: NSRegularExpression, field: WritableKeyPath<ScanResult, ScanField<Double>?>)] = [
        (regex(#"valor\s+energ[eé]tico|calorias"#), \.calories),
        (regex(#"prote[ií]nas?"#), \.protein),
        (regex(#"carboidratos?"#), \.carbs),
        (regex(#"gorduras?\s+totais?"#), \.fat),
        (regex(#"fibra\s+aliment(ar)?"#), \.fiber),
        (regex(#"s[oó]dio"#), \.sodium),
    ]

    private static let portionPattern = regex(#"por[cç][aã]o\D*?(\d+[.,]?\d*)\s*(g|ml)"#)
    private static let per100Pattern = regex(#"(?:por\s*)?100\s*(g|ml)"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func parseNumber(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    private static func firstNumber(in text: String) -> Double? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = numberPattern.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return parseNumber(String(text[swiftRange]))
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Uma linha "quase só número" (permite unidade/observação curta junto,
    /// ex: "120 kcal") — usada no fallback de duas colunas.
    private static func isBareNumberLine(_ text: String) -> Bool {
        let stripped = text.replacingOccurrences(of: #"[\d.,\s%a-zA-ZÀ-ÿ()]"#, with: "", options: .regularExpression)
        return stripped.isEmpty && firstNumber(in: text) != nil && text.count < 20
    }

    public static func parse(lines: [OCRLine]) -> ScanResult {
        var result = ScanResult()
        var consumedNumberLines = Set<Int>()

        // Porção e base de referência (100 g / 100 ml / porção).
        for line in lines {
            if let match = portionPattern.firstMatch(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)),
               let qtyRange = Range(match.range(at: 1), in: line.text),
               let unitRange = Range(match.range(at: 2), in: line.text) {
                result.portionSize = ScanField(value: parseNumber(String(line.text[qtyRange])) ?? 0, confidence: line.confidence)
                result.portionUnit = String(line.text[unitRange]).lowercased() == "ml" ? .ml : .g
            }
            if matches(per100Pattern, line.text) {
                result.nutritionBasis = line.text.lowercased().contains("ml") ? .per100ml : .per100g
            }
        }
        if result.nutritionBasis == nil && result.portionSize != nil {
            result.nutritionBasis = .serving
        }

        // Passo 1: rótulo e número na mesma linha (formato de uma coluna).
        for (index, line) in lines.enumerated() {
            for (keywordRegex, field) in keywordPatterns {
                guard result[keyPath: field] == nil, matches(keywordRegex, line.text) else { continue }
                if let value = firstNumber(in: line.text) {
                    result[keyPath: field] = ScanField(value: value, confidence: line.confidence)
                    consumedNumberLines.insert(index)
                }
            }
        }

        // Passo 2 (fallback): rótulo sozinho numa linha, número na próxima
        // linha "solta" ainda não usada — comum em tabelas de duas colunas.
        let unusedNumberLines = lines.enumerated()
            .filter { !consumedNumberLines.contains($0.offset) && isBareNumberLine($0.element.text) }
        var numberQueue = unusedNumberLines.map { $0 }
        var queueIndex = 0

        for line in lines {
            for (keywordRegex, field) in keywordPatterns {
                guard result[keyPath: field] == nil, matches(keywordRegex, line.text) else { continue }
                guard queueIndex < numberQueue.count else { continue }
                let numberLine = numberQueue[queueIndex].element
                if let value = firstNumber(in: numberLine.text) {
                    result[keyPath: field] = ScanField(value: value, confidence: min(line.confidence, numberLine.confidence))
                    queueIndex += 1
                }
            }
        }

        result.rawText = lines.map(\.text).joined(separator: "\n")
        return result
    }
}
