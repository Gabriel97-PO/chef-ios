import SwiftUI
import SwiftData
import ChefCore

/// Tela de confirmação do scanner (seção 20/21 do plano de migração):
/// campos editáveis com confiança visual 🟢/🟡/🔴, porção interativa que
/// recalcula tudo na hora, e o veredito "Cabe na dieta?". Dados de meta/
/// consumo ainda fixos nesta fase — entram do estado real do app na Fase 4.
struct ScanResultSheet: View {
    let scanResult: ScanResult
    var onAdded: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [SDUserProfile]
    @Query private var allMeals: [SDMealEntry]
    @Query(sort: \SDDietVersion.importedAt, order: .reverse) private var dietVersions: [SDDietVersion]
    @State private var showSlotPicker = false

    @State private var name: String
    @State private var portionSize: Double
    @State private var portionUnit: PortionUnit
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fiber: Double?
    @State private var sodium: Double?
    @State private var quantity: Double
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 32

    private var confidenceByField: [String: Double?]

    init(scanResult: ScanResult) {
        self.scanResult = scanResult
        _name = State(initialValue: scanResult.name?.value ?? "Alimento escaneado")
        _portionSize = State(initialValue: scanResult.portionSize?.value ?? 100)
        _portionUnit = State(initialValue: scanResult.portionUnit ?? .g)
        _calories = State(initialValue: scanResult.calories?.value)
        _protein = State(initialValue: scanResult.protein?.value)
        _carbs = State(initialValue: scanResult.carbs?.value)
        _fat = State(initialValue: scanResult.fat?.value)
        _fiber = State(initialValue: scanResult.fiber?.value)
        _sodium = State(initialValue: scanResult.sodium?.value)
        _quantity = State(initialValue: scanResult.portionSize?.value ?? 100)
        confidenceByField = [
            "calories": scanResult.calories?.confidence,
            "protein": scanResult.protein?.confidence,
            "carbs": scanResult.carbs?.confidence,
            "fat": scanResult.fat?.confidence,
            "fiber": scanResult.fiber?.confidence,
            "sodium": scanResult.sodium?.confidence,
        ]
    }

    private var previewNutrition: NutritionFacts {
        let baseQuantity = portionSize > 0 ? portionSize : 100
        let factor = quantity / baseQuantity
        return NutritionFacts(
            calories: (calories ?? 0) * factor,
            protein: (protein ?? 0) * factor,
            carbs: (carbs ?? 0) * factor,
            fat: (fat ?? 0) * factor,
            fiber: fiber.map { $0 * factor },
            sodium: sodium.map { $0 * factor }
        )
    }

    private var goal: DailyGoal {
        profiles.first?.goal ?? DailyGoal(calories: 2100, protein: 170)
    }

    private var consumedToday: NutritionFacts {
        let today = DateKey.today()
        return NutritionEngine.sumMeals(allMeals.filter { $0.date == today }.map(\.asMealEntry))
    }

    private var fit: FoodFitResult {
        NutritionEngine.analyzeFoodFit(food: previewNutrition, dailyGoal: goal, consumedToday: consumedToday)
    }

    private var missingRequiredFields: Bool {
        calories == nil || protein == nil
    }

    /// Correspondência com a dieta prescrita (seção 18/39): só afirma
    /// "produto corresponde" quando há um item com nome equivalente na
    /// dieta ativa — nunca assume que uma diferença de produto é uma
    /// substituição válida.
    private var prescribedMatch: CnpFoodItem? {
        guard let active = dietVersions.first(where: { $0.active }) else { return nil }
        return CNPMatching.findPrescribedMatch(in: active.document, foodName: name)
    }

    private var differsFromPrescribed: Bool {
        guard let active = dietVersions.first(where: { $0.active }) else { return false }
        return CNPMatching.hasPrescribedFoods(active.document) && prescribedMatch == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Tabela identificada", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chefSuccess)

                TextField("Nome do alimento", text: $name)
                    .font(.title2.weight(.black))

                HStack(spacing: 6) {
                    Text("Porção:")
                        .foregroundStyle(.secondary)
                    TextField("Porção", value: $portionSize, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                    Text(portionUnit == .ml ? "ml" : "g")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                if let prescribedMatch {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✓ Produto corresponde ao item da sua dieta")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.chefSuccess)
                        Text("Prescrito: \(Int(prescribedMatch.quantity))\(prescribedMatch.unit == .g ? "g" : "ml") · Escaneado: \(Int(portionSize))\(portionUnit == .ml ? "ml" : "g")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.chefSuccess.opacity(0.1), in: .rect(cornerRadius: 12))
                } else if differsFromPrescribed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Este produto é diferente dos itens da sua dieta prescrita.")
                            .font(.caption.weight(.semibold))
                        Text("Isso não significa que ele não sirva — apenas que não está na sua lista prescrita.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                }

                HStack(spacing: 16) {
                    metric(value: previewNutrition.calories, unit: "kcal", tint: .chefPrimary)
                    metric(value: previewNutrition.protein, unit: "g proteína", tint: .chefSuccess)
                }
                .frame(maxWidth: .infinity)
                .chefGlassCard(cornerRadius: 24, padding: 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    field("Carboidratos", value: $carbs, key: "carbs")
                    field("Gorduras", value: $fat, key: "fat")
                    field("Fibras", value: $fiber, key: "fiber")
                    field("Sódio (mg)", value: $sodium, key: "sodium")
                    field("Calorias (kcal)", value: $calories, key: "calories")
                    field("Proteína (g)", value: $protein, key: "protein")
                }

                VStack(spacing: 8) {
                    Text("QUANTO VOCÊ VAI CONSUMIR?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Stepper(value: $quantity, in: 0...2000, step: 10) {
                        Text("\(Int(quantity)) \(portionUnit == .ml ? "ml" : "g")")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("CABE NA SUA DIETA?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FitBadge(status: fit.status)
                    Text(fit.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .chefGlassCard(cornerRadius: 24, padding: 20)

                if missingRequiredFields {
                    Text("Preencha os campos não identificados (🔴) para adicionar.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    showSlotPicker = true
                } label: {
                    Text("Adicionar ao dia")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.chefPrimary)
                .disabled(missingRequiredFields)
            }
            .padding(20)
        }
        .confirmationDialog("Adicionar em qual refeição?", isPresented: $showSlotPicker, titleVisibility: .visible) {
            ForEach(MealSlot.allCases) { slot in
                Button(slot.label) { addToDay(slot: slot) }
            }
        }
        .chefKeyboardDismissToolbar()
    }

    private func addToDay(slot: MealSlot) {
        let food = SDFood(
            name: name,
            baseUnit: portionUnit,
            baseQuantity: portionSize > 0 ? portionSize : 100,
            nutrition: NutritionFacts(calories: calories ?? 0, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0, fiber: fiber, sodium: sodium),
            isCustom: true,
            source: .scanner
        )
        context.insert(food)

        let entry = FoodEntry(foodId: food.id, name: name, quantity: quantity, unit: portionUnit, nutrition: previewNutrition)
        MealStore.addItems([entry], date: DateKey.today(), slot: slot, in: context)

        Haptics.success()
        onAdded?()
        dismiss()
    }

    @ViewBuilder
    private func metric(value: Double, unit: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: metricSize, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func field(_ label: String, value: Binding<Double?>, key: String) -> some View {
        let tier = confidenceTier(confidenceByField[key] ?? nil)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tierColor(tier))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TextField(tier == .unrecognized ? "não identificado" : "", text: stringBinding(for: value))
                .keyboardType(.decimalPad)
                .font(.headline)
                .accessibilityLabel("\(label), confiança \(confidenceDescription(tier))")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tierColor(tier).opacity(tier == .high ? 0.06 : 0.14), in: .rect(cornerRadius: 14))
    }

    private func stringBinding(for value: Binding<Double?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue.map { $0.formatted(.number) } ?? "" },
            set: { newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                value.wrappedValue = normalized.isEmpty ? nil : Double(normalized)
            }
        )
    }

    private func confidenceDescription(_ tier: ConfidenceTier) -> String {
        switch tier {
        case .high: return "alta"
        case .review: return "revisar"
        case .unrecognized: return "não identificado"
        }
    }

    private func tierColor(_ tier: ConfidenceTier) -> Color {
        switch tier {
        case .high: return .chefSuccess
        case .review: return .orange
        case .unrecognized: return .red
        }
    }
}

private struct FitBadge: View {
    let status: FitStatus

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .fits: return "🟢 Cabe bem"
        case .attention: return "🟡 Cabe, mas atenção"
        case .doesNotFit: return "🔴 Não cabe agora"
        }
    }

    private var color: Color {
        switch status {
        case .fits: return .chefSuccess
        case .attention: return .orange
        case .doesNotFit: return .red
        }
    }
}

#Preview {
    ScanResultSheet(scanResult: ScanResult(
        name: ScanField(value: "Frango empanado", confidence: 0.95),
        portionSize: ScanField(value: 100, confidence: 0.9),
        portionUnit: .g,
        nutritionBasis: .per100g,
        calories: ScanField(value: 220, confidence: 0.95),
        protein: ScanField(value: 18, confidence: 0.92),
        carbs: ScanField(value: 15, confidence: 0.4),
        fat: ScanField(value: 9, confidence: 0.9)
    ))
}
