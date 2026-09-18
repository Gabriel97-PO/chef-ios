import SwiftUI
import SwiftData
import ChefCore

/// Busca um alimento já cadastrado e adiciona à lista com uma quantidade —
/// componente compartilhado entre criação de refeição fixa e de receita
/// (seção 10 do plano de migração: "componentes devem ser reutilizáveis").
///
/// A busca cruza dois lugares: os alimentos que o usuário já cadastrou
/// (`foods`) e uma base de referência com valores médios de alimentos
/// comuns (`ReferenceFoodDatabase` — "linguiça", "contra filé", "batata
/// inglesa" etc), pra quando o que a pessoa procura ainda não existe
/// localmente. Escolher um item da base de referência grava um `SDFood`
/// de verdade na hora (fonte `.seed`) — na próxima busca ele já aparece
/// como "meu alimento", sem duplicar a entrada da base de referência.
struct IngredientPicker: View {
    @Binding var ingredients: [RecipeIngredient]
    let foods: [SDFood]

    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var selectedFood: SDFood?
    @State private var quantity: Double = 100

    private var localMatches: [SDFood] {
        guard !query.isEmpty else { return [] }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(6).map { $0 }
    }

    /// Só mostra itens da base de referência que o usuário ainda não tem
    /// cadastrado localmente com o mesmo nome — evita listar "Banana" duas
    /// vezes se a pessoa já escaneou/criou a própria.
    private var referenceMatches: [ReferenceFood] {
        guard !query.isEmpty else { return [] }
        let localNames = Set(foods.map { normalizeText($0.name) })
        return ReferenceFoodDatabase.search(query)
            .filter { !localNames.contains(normalizeText($0.name)) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !ingredients.isEmpty {
                ForEach(ingredients) { ingredient in
                    HStack {
                        Text("\(Int(ingredient.quantity))\(unitLabel(ingredient.unit)) \(ingredient.name)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(ingredient.nutrition.calories)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            ingredients.removeAll { $0.id == ingredient.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                }
            }

            if let selectedFood {
                HStack(spacing: 8) {
                    Text(selectedFood.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    TextField("Qtd", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text(unitLabel(selectedFood.baseUnit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Adicionar") { addIngredient(selectedFood) }
                        .font(.caption.weight(.bold))
                    Button {
                        self.selectedFood = nil
                        query = ""
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.chefPrimary.opacity(0.08), in: .rect(cornerRadius: 12))
            } else {
                TextField("Buscar ingrediente…", text: $query)
                    .padding(10)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))

                if !localMatches.isEmpty || !referenceMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(localMatches, id: \.id) { food in
                            matchRow(food.name, detail: nil) {
                                selectedFood = food
                                quantity = food.baseQuantity
                                query = ""
                            }
                        }
                        ForEach(referenceMatches) { reference in
                            matchRow(reference.name, detail: "\(Int(reference.per100.calories)) kcal/100\(unitLabel(reference.unit)) · média") {
                                selectLocalFood(from: reference)
                            }
                        }
                    }
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private func matchRow(_ name: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
                if let detail {
                    Spacer()
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    /// Materializa um item da base de referência como `SDFood` de verdade,
    /// gravado no dispositivo — nunca fica só "na memória": na próxima
    /// busca ele aparece junto dos alimentos que o usuário já cadastrou.
    private func selectLocalFood(from reference: ReferenceFood) {
        let food = FoodStore.create(
            SDFood(
                name: reference.name,
                baseUnit: reference.unit,
                baseQuantity: 100,
                nutrition: reference.per100,
                isCustom: false,
                source: .seed
            ),
            in: context
        )
        selectedFood = food
        quantity = 100
        query = ""
    }

    private func addIngredient(_ food: SDFood) {
        let nutrition = NutritionEngine.calculatePortion(food: food.asFood, quantity: quantity)
        ingredients.append(RecipeIngredient(foodId: food.id, name: food.name, quantity: quantity, unit: food.baseUnit, nutrition: nutrition))
        selectedFood = nil
        query = ""
        quantity = 100
    }

    private func unitLabel(_ unit: PortionUnit) -> String {
        switch unit {
        case .g: return "g"
        case .ml: return "ml"
        case .unidade: return "un"
        }
    }
}
