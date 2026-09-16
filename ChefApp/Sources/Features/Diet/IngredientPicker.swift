import SwiftUI
import SwiftData
import ChefCore

/// Busca um alimento já cadastrado e adiciona à lista com uma quantidade —
/// componente compartilhado entre criação de refeição fixa e de receita
/// (seção 10 do plano de migração: "componentes devem ser reutilizáveis").
struct IngredientPicker: View {
    @Binding var ingredients: [RecipeIngredient]
    let foods: [SDFood]

    @State private var query = ""
    @State private var selectedFood: SDFood?
    @State private var quantity: Double = 100

    private var matches: [SDFood] {
        guard !query.isEmpty else { return [] }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(6).map { $0 }
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

                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(matches, id: \.id) { food in
                            Button {
                                selectedFood = food
                                quantity = food.baseQuantity
                                query = ""
                            } label: {
                                Text(food.name)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
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
