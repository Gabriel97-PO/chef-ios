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

    @State private var isSearchingOnline = false
    @State private var onlineResults: [NetworkFoodResult] = []
    @State private var onlineError: String?

    private var pending: [SDShoppingListItem] { items.filter { !$0.checked } }
    private var checked: [SDShoppingListItem] { items.filter { $0.checked } }

    private var showSuggestions: Bool {
        !newItemName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var localSuggestions: [ReferenceFood] {
        guard showSuggestions else { return [] }
        return ReferenceFoodDatabase.search(newItemName).prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    Haptics.selection()
                    ShoppingListStore.mergeFromDiet(fixedMeals: fixedMeals, recipes: recipes, in: context)
                } label: {
                    Label("Adicionar da dieta", systemImage: "arrow.down.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chefOnPrimary)
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

            // Sem refeição fixa nem receita cadastrada, o botão acima fica
            // desabilitado sem nenhuma explicação — deixa claro o porquê
            // em vez de um botão cinza mudo.
            if fixedMeals.isEmpty && recipes.isEmpty {
                Text("Cadastre refeições fixas ou receitas na aba Dieta para puxar os itens automaticamente aqui.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            addItemField

            if showSuggestions {
                suggestionsSection
            }

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
                .onChange(of: newItemName) { _, _ in
                    onlineResults = []
                    onlineError = nil
                }
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

    // MARK: - Busca (local + online), mesma camada do IngredientPicker

    @ViewBuilder
    private var suggestionsSection: some View {
        if !localSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(localSuggestions) { reference in
                    suggestionRow(reference.name, detail: "\(Int(reference.per100.calories)) kcal/100\(unitAbbreviation(reference.unit)) · média") {
                        pick(reference.name, unit: reference.unit)
                    }
                }
            }
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
        } else if isSearchingOnline {
            HStack(spacing: 8) {
                ProgressView()
                Text("Buscando \"\(newItemName)\" online…").font(.caption)
            }
            .padding(10)
        } else if !onlineResults.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(onlineResults) { result in
                    suggestionRow(result.name, detail: "\(Int(result.per100g.calories)) kcal/100g · online") {
                        pick(result.name, unit: .g)
                    }
                }
            }
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Task { await searchOnline() }
                } label: {
                    Label("Buscar \"\(newItemName)\" online", systemImage: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
                .buttonStyle(.bordered)
                .tint(Color.chefPrimary)

                if let onlineError {
                    Label(onlineError, systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func suggestionRow(_ name: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name).font(.subheadline).lineLimit(1)
                Spacer()
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    private func pick(_ name: String, unit: PortionUnit) {
        newItemName = name
        newItemUnit = unit
        onlineResults = []
    }

    private func searchOnline() async {
        isSearchingOnline = true
        onlineError = nil
        defer { isSearchingOnline = false }
        do {
            onlineResults = try await OpenFoodFactsService.search(newItemName)
        } catch {
            onlineResults = []
            onlineError = error.localizedDescription
            Haptics.error()
        }
    }

    private func unitAbbreviation(_ unit: PortionUnit) -> String {
        switch unit {
        case .g: return "g"
        case .ml: return "ml"
        case .unidade: return "un"
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
