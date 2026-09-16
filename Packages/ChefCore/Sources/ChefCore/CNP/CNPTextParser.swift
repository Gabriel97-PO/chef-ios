import Foundation

/// Parser de importação de dieta.
///
/// POR QUE EXISTE:
/// Interpretar um PDF/DOCX de nutricionista com estrutura livre exige OCR +
/// um modelo de IA semântica — isso fica atrás de um serviço próprio
/// (`AIService`/backend), nunca embutido com credenciais no app. Este
/// parser cobre o que dá pra fazer sem IA:
///
/// 1. Se o texto colado já é um documento CNP em JSON válido, usa-o direto
///    — o caminho de maior confiança, pensado para softwares de nutrição
///    que exportem no formato Chef Nutrition Protocol.
/// 2. Caso contrário, roda um parser heurístico sobre um template de texto
///    estruturado (PACIENTE/CALORIAS/PROTEÍNA/refeições em maiúsculas com
///    linhas "quantidade unidade alimento"), reconhecendo refeições comuns
///    e alternativas separadas por "OU". Qualquer linha que não se encaixe
///    em nenhum padrão vira uma ambiguidade explícita — nunca é descartada
///    ou adivinhada ("não encontrado ≠ zero ≠ estimado ≠ inventado").
public enum CNPTextParser {

    private static let mealKeywords = [
        "café da manhã", "cafe da manha", "almoço", "almoco",
        "lanche", "jantar", "pós-treino", "pos-treino", "pós treino", "ceia",
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static let caloriesPattern = regex(#"calorias?\s*[:-]?\s*(\d+[.,]?\d*)"#)
    private static let proteinPattern = regex(#"prote[ií]nas?\s*[:-]?\s*(\d+[.,]?\d*)"#)
    private static let carbsPattern = regex(#"carboidratos?\s*[:-]?\s*(\d+[.,]?\d*)"#)
    private static let fatPattern = regex(#"gorduras?\s*[:-]?\s*(\d+[.,]?\d*)"#)
    private static let foodLinePattern = regex(#"^(\d+[.,]?\d*)\s*(g|ml|unidade|un\.?|ovos?)?\s+(.+)$"#)
    private static let patientPattern = regex(#"^paciente\s*[:-]?\s*(.+)$"#)
    private static let mealHeaderStrip = regex(#"[:–-].*$"#)
    private static let labelPrefixPattern = regex(
        #"^(paciente|objetivos|calorias|prote[ií]na|carboidratos|gorduras|água|agua|substitui|observ|grupo|refeição|refeicao)"#
    )

    private static func firstMatch(_ regex: NSRegularExpression, in text: String, group: Int = 1) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.range(at: group).location != NSNotFound,
              let swiftRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func parseNumber(_ raw: String) -> Double {
        Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private static func normalizeUnit(_ raw: String?) -> CnpUnit {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return .unit }
        if raw.hasPrefix("g") { return .g }
        if raw.hasPrefix("ml") { return .ml }
        return .unit
    }

    private static func isMealHeader(_ line: String) -> String? {
        let stripped = mealHeaderStrip.stringByReplacingMatches(
            in: line, range: NSRange(line.startIndex..., in: line), withTemplate: ""
        )
        let lower = normalizeText(stripped)
        if mealKeywords.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
            return line.trimmingCharacters(in: .whitespaces)
        }
        if line.range(of: #"^nome\s*:"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return line.replacingOccurrences(of: #"^nome\s*:"#, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parsePatientName(_ lines: [String]) -> String {
        for line in lines {
            if let name = firstMatch(patientPattern, in: line) {
                return name.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Paciente"
    }

    private static func extractGoals(_ lines: [String]) -> (goals: CnpGoals, foundCalories: Bool, foundProtein: Bool) {
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?

        for line in lines {
            if calories == nil, let raw = firstMatch(caloriesPattern, in: line) { calories = parseNumber(raw) }
            if protein == nil, let raw = firstMatch(proteinPattern, in: line) { protein = parseNumber(raw) }
            if carbs == nil, let raw = firstMatch(carbsPattern, in: line) { carbs = parseNumber(raw) }
            if fat == nil, let raw = firstMatch(fatPattern, in: line) { fat = parseNumber(raw) }
        }

        return (
            CnpGoals(calories: calories ?? 0, proteinG: protein ?? 0, carbohydratesG: carbs, fatG: fat),
            calories != nil,
            protein != nil
        )
    }

    private static func parseMeals(_ lines: [String]) -> (meals: [CnpMeal], ambiguities: [String]) {
        var meals: [CnpMeal] = []
        var ambiguities: [String] = []
        var current: CnpMeal?

        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if let mealName = isMealHeader(line) {
                if let current { meals.append(current) }
                current = CnpMeal(name: mealName, foods: [])
                continue
            }

            guard current != nil else { continue }

            if normalizeText(line) == "ou" { continue }

            let range = NSRange(line.startIndex..., in: line)
            if let match = foodLinePattern.firstMatch(in: line, range: range),
               let quantityRange = Range(match.range(at: 1), in: line),
               let nameRange = Range(match.range(at: 3), in: line) {
                let unitRaw = match.range(at: 2).location != NSNotFound ? Range(match.range(at: 2), in: line).map { String(line[$0]) } : nil
                let item = CnpFoodItem(
                    name: String(line[nameRange]).trimmingCharacters(in: .whitespaces),
                    quantity: parseNumber(String(line[quantityRange])),
                    unit: normalizeUnit(unitRaw)
                )

                let previousLine = i > 0 ? lines[i - 1].trimmingCharacters(in: .whitespaces) : ""
                let isAlternative = normalizeText(previousLine) == "ou"

                if isAlternative, var meal = current, let last = meal.foods.last {
                    var substitutions = meal.substitutions ?? []
                    if let idx = substitutions.firstIndex(where: { $0.options.contains(where: { $0.name == last.name }) }) {
                        substitutions[idx].options.append(item)
                    } else {
                        substitutions.append(CnpSubstitutionGroup(group: last.name, options: [last, item]))
                        meal.foods.removeLast()
                    }
                    meal.substitutions = substitutions
                    current = meal
                } else {
                    current?.foods.append(item)
                }
                continue
            }

            if labelPrefixPattern.firstMatch(in: line, range: range) != nil {
                continue // rótulos estruturais do template — não são ambiguidade
            }

            ambiguities.append(line)
        }

        if let current { meals.append(current) }
        return (meals, ambiguities)
    }

    /// Tenta interpretar o texto como um documento CNP em JSON. Retorna
    /// `nil` (nunca lança) quando o texto não é um JSON de dieta válido, pra
    /// cair no caminho heurístico sem quebrar a importação.
    private static func tryParseJson(_ text: String) -> CnpDocument? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CnpDocument.self, from: data)
    }

    public static func parse(text: String) -> CnpImportResult {
        if let document = tryParseJson(text) {
            let foodCount = document.meals.reduce(0) { $0 + $1.foods.count }
            let substitutionCount = document.meals.reduce(0) { $0 + ($1.substitutions?.count ?? 0) }
            return CnpImportResult(
                document: document,
                summary: CnpImportSummary(
                    foundCalorieGoal: document.goals.calories > 0,
                    foundProteinGoal: document.goals.proteinG > 0,
                    mealCount: document.meals.count,
                    foodCount: foodCount,
                    substitutionCount: substitutionCount,
                    ambiguities: []
                ),
                sourceText: text
            )
        }

        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let patientName = parsePatientName(lines)
        let (goals, foundCalories, foundProtein) = extractGoals(lines)
        let (meals, ambiguities) = parseMeals(lines)

        let document = CnpDocument(patient: CnpPatient(name: patientName), goals: goals, meals: meals)
        let foodCount = meals.reduce(0) { $0 + $1.foods.count }
        let substitutionCount = meals.reduce(0) { $0 + ($1.substitutions?.count ?? 0) }

        return CnpImportResult(
            document: document,
            summary: CnpImportSummary(
                foundCalorieGoal: foundCalories,
                foundProteinGoal: foundProtein,
                mealCount: meals.count,
                foodCount: foodCount,
                substitutionCount: substitutionCount,
                ambiguities: ambiguities
            ),
            sourceText: text
        )
    }
}
