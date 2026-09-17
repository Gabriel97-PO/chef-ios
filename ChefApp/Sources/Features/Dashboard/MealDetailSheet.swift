import SwiftUI
import SwiftData
import ChefCore

/// Detalhe de uma refeição registrada, aberto ao tocar num card da Home —
/// antes os cards só mostravam o total, sem forma de ver ou remover os
/// itens de fato registrados.
struct MealDetailSheet: View {
    let slot: MealSlot
    let meal: SDMealEntry?
    let dateLabel: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var items: [FoodEntry] { meal?.items ?? [] }
    private var totals: NutritionFacts { NutritionEngine.sumNutrition(items.map(\.nutrition)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if items.isEmpty {
                        ContentUnavailableView(
                            "Nada registrado",
                            systemImage: "fork.knife",
                            description: Text("Você ainda não registrou nada em \(slot.label.lowercased()) \(dateLabel).")
                        )
                        .padding(.top, 40)
                    } else {
                        HStack(spacing: 16) {
                            metric(value: totals.calories, unit: "kcal", tint: .chefPrimary)
                            metric(value: totals.protein, unit: "g proteína", tint: .chefSuccess)
                        }
                        .chefGlassCard(cornerRadius: 20, padding: 16)

                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                itemRow(item)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(slot.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

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

    private func itemRow(_ item: FoodEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline.weight(.semibold))
                Text("\(Int(item.quantity))\(item.unit == .unidade ? "x" : item.unit.rawValue) · \(Int(item.nutrition.calories)) kcal · \(item.nutrition.protein.formatted(.number.precision(.fractionLength(1))))g")
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

    private func removeItem(_ item: FoodEntry) {
        guard let meal else { return }
        Haptics.selection()
        MealStore.removeItem(mealID: meal.id, itemID: item.id, in: context)
    }
}
