import SwiftUI
import SwiftData
import ChefCore

/// Lista de compras (seção 21 da especificação "Será que eu posso?"):
/// gerada a partir das refeições fixas e receitas cadastradas, ou editada
/// à mão. Item marcado fica riscado; "Limpar marcados" tira os já
/// comprados de uma vez.
struct ShoppingListView: View {
    let fixedMeals: [SDFixedMeal]
    let recipes: [SDRecipe]

    @Environment(\.modelContext) private var context
    @Query(sort: \SDShoppingListItem.createdAt) private var items: [SDShoppingListItem]

    @State private var newItemName = ""
    @State private var newItemQuantity: Double = 1
    @State private var newItemUnit: PortionUnit = .unidade

    private var pending: [SDShoppingListItem] { items.filter { !$0.checked } }
    private var checked: [SDShoppingListItem] { items.filter { $0.checked } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    Haptics.selection()
                    ShoppingListStore.mergeFromDiet(fixedMeals: fixedMeals, recipes: recipes, in: context)
                } label: {
                    Label("Adicionar da dieta", systemImage: "arrow.down.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chefPrimary)
                .disabled(fixedMeals.isEmpty && recipes.isEmpty)

                Spacer()

                if !checked.isEmpty {
                    Button("Limpar marcados") {
                        Haptics.selection()
                        ShoppingListStore.clearChecked(in: context)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }

            addItemField

            if items.isEmpty {
                Text("Sua lista está vazia. Adicione um item ou puxe da dieta.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(pending) { item in
                        row(item)
                    }
                    if !checked.isEmpty {
                        Text("COMPRADOS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                        ForEach(checked) { item in
                            row(item)
                        }
                    }
                }
            }
        }
    }

    private var addItemField: some View {
        HStack(spacing: 8) {
            TextField("Adicionar item…", text: $newItemName)
                .padding(10)
                .background(.thinMaterial, in: .rect(cornerRadius: 12))
            TextField("Qtd", value: $newItemQuantity, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
            Picker("Unidade", selection: $newItemUnit) {
                Text("un").tag(PortionUnit.unidade)
                Text("g").tag(PortionUnit.g)
                Text("ml").tag(PortionUnit.ml)
            }
            .pickerStyle(.menu)
            .tint(Color.chefPrimary)
            Button {
                guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                ShoppingListStore.add(name: newItemName, quantity: newItemQuantity, unit: newItemUnit, in: context)
                newItemName = ""
                newItemQuantity = 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.chefPrimary)
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func row(_ item: SDShoppingListItem) -> some View {
        Button {
            Haptics.selection()
            ShoppingListStore.toggle(item, in: context)
        } label: {
            HStack {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.checked ? Color.chefSuccess : .secondary)
                Text("\(quantityLabel(item)) \(item.name)")
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? .secondary : .primary)
                Spacer()
                Button {
                    ShoppingListStore.remove(item, in: context)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func quantityLabel(_ item: SDShoppingListItem) -> String {
        switch item.unit {
        case .unidade: return "\(Int(item.quantity))x"
        case .g: return "\(Int(item.quantity))g"
        case .ml: return "\(Int(item.quantity))ml"
        }
    }
}
