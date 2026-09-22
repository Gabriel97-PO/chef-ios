import Foundation

/// Um item agrupado de lista de compras.
public struct ShoppingListEntry: Sendable, Equatable {
    public var name: String
    public var quantity: Double
    public var unit: PortionUnit

    public init(name: String, quantity: Double, unit: PortionUnit) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}

/// Agrupa ingredientes de refeições fixas/receitas numa lista de compras
/// (seção 21: "agrupar ingredientes; somar quantidades"). Pura função de
/// agregação — quem decide o que persistir/marcar como comprado é a
/// camada de app (`ShoppingListStore`), isso aqui só soma.
public enum ShoppingListBuilder {
    /// Agrupa por nome normalizado (sem acento/caixa) + unidade — dois
    /// itens só se somam quando são o mesmo alimento na mesma unidade;
    /// "200 g arroz" e "1 unidade arroz" (erro de cadastro, mas possível)
    /// nunca viram uma soma sem sentido, ficam como entradas separadas.
    public static func aggregate(_ items: [(name: String, quantity: Double, unit: PortionUnit)]) -> [ShoppingListEntry] {
        var order: [String] = []
        var totals: [String: ShoppingListEntry] = [:]

        for item in items {
            guard item.quantity > 0 else { continue }
            let key = normalizeText(item.name) + "|" + item.unit.rawValue
            if var existing = totals[key] {
                existing.quantity += item.quantity
                totals[key] = existing
            } else {
                totals[key] = ShoppingListEntry(name: item.name, quantity: item.quantity, unit: item.unit)
                order.append(key)
            }
        }

        return order.compactMap { totals[$0] }
    }

    public static func fromFixedMeals(_ fixedMeals: [FixedMeal]) -> [ShoppingListEntry] {
        aggregate(fixedMeals.flatMap { $0.items.map { (name: $0.name, quantity: $0.quantity, unit: $0.unit) } })
    }

    public static func fromRecipes(_ recipes: [Recipe]) -> [ShoppingListEntry] {
        aggregate(recipes.flatMap { $0.ingredients.map { (name: $0.name, quantity: $0.quantity, unit: $0.unit) } })
    }
}
