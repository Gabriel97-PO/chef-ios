import Foundation

extension MealSlot {
    /// Descobre a refeição do dia a partir do nome escrito pela
    /// nutricionista ("ALMOÇO", "Café da manhã", "Ceia", "Lanche da
    /// tarde"...). Usado pra amarrar as refeições fixas importadas via CNP
    /// aos horários da aba Hoje (roadmap item 5).
    ///
    /// Devolve `nil` quando o nome não casa com nada conhecido — quem
    /// chama decide o que fazer, em vez de a gente empurrar tudo pra
    /// `.outro` e fingir que entendeu.
    public static func inferred(fromName name: String) -> MealSlot? {
        let text = normalizeText(name)

        // Ordem importa: "lanche da manha" tem que casar com lanche, não
        // com café da manhã, então os termos mais específicos vêm antes.
        let patterns: [(MealSlot, [String])] = [
            (.posTreino, ["pos treino", "postreino", "pos-treino", "apos treino", "pos workout"]),
            (.lanche, ["lanche", "colacao", "merenda", "snack"]),
            (.cafeDaManha, ["cafe da manha", "cafe manha", "desjejum", "breakfast", "cafe"]),
            (.almoco, ["almoco", "lunch"]),
            (.jantar, ["jantar", "janta", "ceia", "dinner"]),
        ]

        for (slot, terms) in patterns where terms.contains(where: text.contains) {
            return slot
        }
        return nil
    }
}
