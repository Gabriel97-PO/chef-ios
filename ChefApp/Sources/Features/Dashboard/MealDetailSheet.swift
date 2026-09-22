import SwiftUI
import SwiftData
import PhotosUI
import ChefCore

/// Detalhe de uma refeição de um dia, aberto ao tocar num card da Home.
///
/// Mostra três coisas, nessa ordem: o que já foi registrado, o que a dieta
/// prescreve para esse horário (roadmap item 5) e um campo pra registrar
/// qualquer outro alimento (item 7). O planejado nunca entra sozinho no
/// dia — aparece como sugestão com um botão, porque "ter dieta" não é o
/// mesmo que "ter comido".
struct MealDetailSheet: View {
    let slot: MealSlot
    let meal: SDMealEntry?
    let dateKey: String
    let dateLabel: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SDFood.name) private var foods: [SDFood]
    @Query(sort: \SDFixedMeal.name) private var fixedMeals: [SDFixedMeal]

    @State private var newItems: [RecipeIngredient] = []
    @State private var addingFood = false
    @State private var photoPickerItem: PhotosPickerItem?

    private var items: [FoodEntry] { meal?.items ?? [] }
    private var totals: NutritionFacts { NutritionEngine.sumNutrition(items.map(\.nutrition)) }

    /// Refeições fixas amarradas a esse horário do dia.
    private var planned: [SDFixedMeal] { fixedMeals.filter { $0.slot == slot } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if items.isEmpty {
                        Label("Nada registrado \(dateLabel)", systemImage: "tray")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 16) {
                            metric(value: totals.calories, unit: "kcal", tint: .chefPrimary)
                            metric(value: totals.protein, unit: "g proteína", tint: .chefSuccess)
                        }
                        .chefGlassCard(cornerRadius: 20, padding: 16)

                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                registeredRow(item)
                            }
                        }

                        photoSection
                    }

                    if !planned.isEmpty {
                        plannedSection
                    }

                    addSection
                }
                .padding()
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(slot.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .chefKeyboardDismissToolbar()
        }
    }

    // MARK: - O que a dieta prescreve (item 5)

    private var plannedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sua dieta para \(slot.label.lowercased())", systemImage: "doc.text.fill")
                .font(.subheadline.weight(.bold))

            ForEach(planned) { fixed in
                let plannedTotals = NutritionEngine.sumNutrition(fixed.items.map(\.nutrition))
                VStack(alignment: .leading, spacing: 8) {
                    Text(fixed.items.map { "\(Int($0.quantity))\(unitLabel($0.unit)) \($0.name)" }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("\(Int(plannedTotals.calories)) kcal · \(plannedTotals.protein.formatted(.number.precision(.fractionLength(1))))g")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button {
                            registerPlanned(fixed)
                        } label: {
                            Label("Registrar", systemImage: "plus.circle.fill")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.chefPrimary)
                        .controlSize(.small)
                    }
                }
                .chefGlassCard(cornerRadius: 14, padding: 12)
            }
        }
    }

    // MARK: - Diário fotográfico (seção 22)

    /// Foto opcional da refeição. Nunca salva sozinha: só grava quando o
    /// usuário escolhe uma foto de propósito (seção 25 — a câmera do
    /// scanner nunca persiste a foto capturada por conta própria).
    @ViewBuilder
    private var photoSection: some View {
        if let data = meal?.photoData, let uiImage = UIImage(data: data) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Button(role: .destructive) {
                    savePhotoData(nil)
                } label: {
                    Label("Remover foto", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
            }
        } else {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Adicionar foto da refeição", systemImage: "camera")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chefPrimary)
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await loadPickedPhoto(newItem) }
            }
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) else { return }
        // Redimensiona pra no máximo ~800px de largura antes de comprimir —
        // uma refeição não precisa de resolução de câmera pra ficar
        // reconhecível, e isso mantém o banco local pequeno.
        let resized = resize(uiImage, maxWidth: 800)
        guard let compressed = resized.jpegData(compressionQuality: 0.6) else { return }
        savePhotoData(compressed)
        photoPickerItem = nil
    }

    private func resize(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func savePhotoData(_ data: Data?) {
        guard let meal else { return }
        meal.photoData = data
        try? context.save()
        Haptics.selection()
    }

    // MARK: - Registrar qualquer alimento (item 7)

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if addingFood {
                Label("Adicionar alimento", systemImage: "plus.circle")
                    .font(.subheadline.weight(.bold))
                IngredientPicker(ingredients: $newItems, foods: foods)
                HStack {
                    Button("Cancelar") {
                        addingFood = false
                        newItems = []
                    }
                    Spacer()
                    Button {
                        registerNewItems()
                    } label: {
                        Label("Registrar \(newItems.count) item\(newItems.count == 1 ? "" : "s")", systemImage: "checkmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.chefPrimary)
                    .disabled(newItems.isEmpty)
                }
            } else {
                Button {
                    addingFood = true
                } label: {
                    Label("Adicionar alimento", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .contentShape(Rectangle())
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
        }
    }

    // MARK: - Componentes

    @ViewBuilder
    private func metric(value: Double, unit: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.formatted(.number.precision(.fractionLength(0))))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func registeredRow(_ item: FoodEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text("\(Int(item.quantity))\(unitLabel(item.unit)) · \(Int(item.nutrition.calories)) kcal · \(item.nutrition.protein.formatted(.number.precision(.fractionLength(1))))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                removeItem(item)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .chefGlassCard(cornerRadius: 14, padding: 12)
    }

    private func unitLabel(_ unit: PortionUnit) -> String {
        switch unit {
        case .g: return "g"
        case .ml: return "ml"
        case .unidade: return "un"
        }
    }

    // MARK: - Ações

    private func registerPlanned(_ fixed: SDFixedMeal) {
        MealStore.addItems(fixed.items, date: dateKey, slot: slot, in: context)
        Haptics.success()
    }

    private func registerNewItems() {
        let entries = newItems.map {
            FoodEntry(foodId: $0.foodId, name: $0.name, quantity: $0.quantity, unit: $0.unit, nutrition: $0.nutrition)
        }
        MealStore.addItems(entries, date: dateKey, slot: slot, in: context)
        Haptics.success()
        newItems = []
        addingFood = false
    }

    private func removeItem(_ item: FoodEntry) {
        guard let meal else { return }
        Haptics.selection()
        MealStore.removeItem(mealID: meal.id, itemID: item.id, in: context)
    }
}
