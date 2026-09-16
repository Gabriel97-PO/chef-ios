import Foundation

public enum CNPMatching {
    /// Procura um alimento com nome equivalente entre os itens prescritos de
    /// uma dieta: tanto os alimentos diretos de cada refeição quanto as
    /// opções dentro de grupos de substituição ("OU") — qualquer uma delas
    /// é, por definição, um item prescrito válido. Nunca afirma
    /// correspondência sem uma comparação de nome real.
    public static func findPrescribedMatch(in document: CnpDocument, foodName: String) -> CnpFoodItem? {
        let target = normalizeText(foodName)
        guard !target.isEmpty else { return nil }

        func matches(_ name: String) -> Bool {
            let n = normalizeText(name)
            return n == target || n.contains(target) || target.contains(n)
        }

        for meal in document.meals {
            if let direct = meal.foods.first(where: { matches($0.name) }) {
                return direct
            }
            for group in meal.substitutions ?? [] {
                if let option = group.options.first(where: { matches($0.name) }) {
                    return option
                }
            }
        }
        return nil
    }

    /// Verdadeiro quando o documento prescreve pelo menos um alimento (direto ou em substituição).
    public static func hasPrescribedFoods(_ document: CnpDocument) -> Bool {
        document.meals.contains { !$0.foods.isEmpty || !($0.substitutions ?? []).isEmpty }
    }

    /// Alimentos "fixos" de uma refeição para fins de cálculo/refeição-fixa:
    /// os itens diretos mais a primeira opção de cada grupo de substituição.
    /// Nunca descarta o grupo silenciosamente — apenas escolhe um padrão
    /// concreto para poder somar calorias/proteína, já que uma refeição
    /// fixa precisa de itens definidos. (Esta é a correção do bug real
    /// encontrado no PWA: substituições sendo descartadas ao aplicar uma
    /// dieta importada — ver commit "fecha o caso negativo...".)
    public static func resolvedFoods(for meal: CnpMeal) -> [CnpFoodItem] {
        let fromSubstitutions = (meal.substitutions ?? []).compactMap(\.options.first)
        return meal.foods + fromSubstitutions
    }
}
