import SwiftUI
import SwiftData
import ChefCore

/// Busca um alimento já cadastrado e adiciona à lista com uma quantidade —
/// componente compartilhado entre criação de refeição fixa e de receita
/// (seção 10 do plano de migração: "componentes devem ser reutilizáveis").
///
/// A busca cruza três lugares, nessa ordem: os alimentos que o usuário já
/// cadastrou (`foods`), uma base de referência com valores médios de
/// alimentos comuns (`ReferenceFoodDatabase`), e — quando nenhum dos dois
/// acha nada — uma busca online (`OpenFoodFactsService`), disparada só sob
/// pedido explícito (não a cada tecla). Escolher qualquer um dos três
/// grava um `SDFood` de verdade na hora (fonte `.seed`) — na próxima busca
/// ele já aparece como "meu alimento".
struct IngredientPicker: View {
    @Binding var ingredients: [RecipeIngredient]
    let foods: [SDFood]

    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var selectedFood: SDFood?
    @State private var quantity: Double = 100
    @State private var inputMode: QuantityInputMode = .weight
    @State private var unitCount: Double = 1

    @State private var isSearchingOnline = false
    @State private var onlineResults: [NetworkFoodResult] = []
    @State private var onlineError: String?

    private enum QuantityInputMode: Hashable {
        case weight, units
    }

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

    private var hasNoLocalMatches: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty && localMatches.isEmpty && referenceMatches.isEmpty
    }

    private var selectedUnitWeight: Double? {
        guard let selectedFood else { return nil }
        return ReferenceFoodDatabase.unitWeightGrams(forFoodNamed: selectedFood.name)
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
                selectedFoodCard(selectedFood)
            } else {
                TextField("Buscar ingrediente…", text: $query)
                    .padding(10)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                    .onChange(of: query) { _, _ in
                        onlineResults = []
                        onlineError = nil
                    }

                if !localMatches.isEmpty || !referenceMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(localMatches, id: \.id) { food in
                            matchRow(food.name, detail: nil) {
                                selectLocalFood(food)
                            }
                        }
                        ForEach(referenceMatches) { reference in
                            matchRow(reference.name, detail: "\(Int(reference.per100.calories)) kcal/100\(unitLabel(reference.unit)) · média") {
                                selectReferenceFood(reference)
                            }
                        }
                    }
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                } else if hasNoLocalMatches {
                    onlineSearchSection
                }
            }
        }
    }

    // MARK: - Busca online

    @ViewBuilder
    private var onlineSearchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSearchingOnline {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Buscando \"\(query)\" online…").font(.caption)
                }
                .padding(10)
            } else if !onlineResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(onlineResults) { result in
                        matchRow(result.name, detail: "\(Int(result.per100g.calories)) kcal/100g · online") {
                            selectOnlineFood(result)
                        }
                    }
                }
                .background(.thinMaterial, in: .rect(cornerRadius: 12))
            } else {
                Button {
                    Task { await searchOnline() }
                } label: {
                    Label("Buscar \"\(query)\" online", systemImage: "magnifyingglass")
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

    private func searchOnline() async {
        isSearchingOnline = true
        onlineError = nil
        defer { isSearchingOnline = false }
        do {
            onlineResults = try await OpenFoodFactsService.search(query)
        } catch {
            onlineResults = []
            onlineError = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Card do alimento selecionado (peso ou unidades)

    @ViewBuilder
    private func selectedFoodCard(_ food: SDFood) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(food.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Button {
                    selectedFood = nil
                    query = ""
                } label: {
                    Image(systemName: "xmark").foregroundStyle(.secondary)
                }
            }

            if let selectedUnitWeight {
                Picker("Modo", selection: $inputMode) {
                    Text("Peso (g)").tag(QuantityInputMode.weight)
                    Text("Unidades").tag(QuantityInputMode.units)
                }
                .pickerStyle(.segmented)
                .onChange(of: inputMode) { _, mode in
                    quantity = mode == .units ? unitCount * selectedUnitWeight : quantity
                }
            }

            HStack(spacing: 8) {
                if inputMode == .units, let selectedUnitWeight {
                    Stepper(value: $unitCount, in: 1...20, step: 1) {
                        Text("\(Int(unitCount)) \(unitCount == 1 ? "unidade" : "unidades")")
                            .font(.subheadline.weight(.semibold))
                    }
                    .onChange(of: unitCount) { _, count in
                        quantity = count * selectedUnitWeight
                    }
                    Text("≈ \(Int(unitCount * selectedUnitWeight))g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Peso:")
                        .foregroundStyle(.secondary)
                    TextField("Qtd", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Text(unitLabel(food.baseUnit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Adicionar") { addIngredient(food) }
                    .font(.caption.weight(.bold))
            }
        }
        .padding(10)
        .background(Color.chefPrimary.opacity(0.08), in: .rect(cornerRadius: 12))
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

    // MARK: - Seleção

    private func selectLocalFood(_ food: SDFood) {
        selectedFood = food
        startQuantity(for: food.name, baseQuantity: food.baseQuantity)
        query = ""
    }

    /// Materializa um item da base de referência como `SDFood` de verdade,
    /// gravado no dispositivo — nunca fica só "na memória": na próxima
    /// busca ele aparece junto dos alimentos que o usuário já cadastrou.
    private func selectReferenceFood(_ reference: ReferenceFood) {
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
        startQuantity(for: food.name, baseQuantity: 100)
        query = ""
    }

    private func selectOnlineFood(_ result: NetworkFoodResult) {
        Haptics.success()
        let food = FoodStore.create(
            SDFood(
                name: result.name,
                baseUnit: .g,
                baseQuantity: 100,
                nutrition: result.per100g,
                isCustom: false,
                source: .seed
            ),
            in: context
        )
        selectedFood = food
        startQuantity(for: food.name, baseQuantity: 100)
        query = ""
        onlineResults = []
    }

    private func startQuantity(for name: String, baseQuantity: Double) {
        if let unitWeight = ReferenceFoodDatabase.unitWeightGrams(forFoodNamed: name) {
            inputMode = .units
            unitCount = 1
            quantity = unitWeight
        } else {
            inputMode = .weight
            quantity = baseQuantity
        }
    }

    private func addIngredient(_ food: SDFood) {
        let nutrition = NutritionEngine.calculatePortion(food: food.asFood, quantity: quantity)
        ingredients.append(RecipeIngredient(foodId: food.id, name: food.name, quantity: quantity, unit: food.baseUnit, nutrition: nutrition))
        selectedFood = nil
        query = ""
        quantity = 100
        inputMode = .weight
        unitCount = 1
    }

    private func unitLabel(_ unit: PortionUnit) -> String {
        switch unit {
        case .g: return "g"
        case .ml: return "ml"
        case .unidade: return "un"
        }
    }
}
