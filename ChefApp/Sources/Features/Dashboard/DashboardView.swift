import SwiftUI
import SwiftData
import ChefCore

/// Tela "Hoje" — responde "como está meu dia?" com hierarquia visual clara
/// (seção 7 do plano de migração). Lê dados reais do SwiftData agora —
/// nada mais fixo como na primeira versão da Fase 1.
///
/// O título fixo "Hoje" virou um seletor de dias da semana (`WeekStripView`,
/// estilo Strava): dá pra consultar o histórico de refeições de qualquer
/// dia da semana atual ou de semanas anteriores, não só o dia corrente.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SDUserProfile]
    @Query private var meals: [SDMealEntry]
    @Query(sort: \SDFixedMeal.name) private var fixedMeals: [SDFixedMeal]
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    @State private var selectedDate = Date()
    @State private var detailSlot: MealSlot?

    private var profile: SDUserProfile? { profiles.first }
    private var selectedDateKey: String { DateKey.string(from: selectedDate) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var mealsForSelectedDate: [SDMealEntry] {
        meals.filter { $0.date == selectedDateKey }
    }

    private var consumed: NutritionFacts {
        NutritionEngine.sumMeals(mealsForSelectedDate.map(\.asMealEntry))
    }

    private var budget: NutritionEngine.RemainingBudget? {
        guard let goal = profile?.goal else { return nil }
        return NutritionEngine.calculateRemainingBudget(goal: goal, consumed: consumed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChefHeader(title: "Hoje")

                    WeekStripView(selectedDate: $selectedDate)

                    if let profile, let budget {
                        let goal = profile.goal
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(spacing: 6) {
                                Text(isToday ? "Hoje" : dayLabel(selectedDate))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(consumed.calories))")
                                    .font(.system(size: heroSize, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                Text("de \(Int(goal.calories)) kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Text("Proteína")
                                        .font(.footnote.weight(.semibold))
                                    Spacer()
                                    Text("\(consumed.protein.formatted(.number.precision(.fractionLength(1)))) / \(Int(goal.protein)) g")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 12)
                            }
                            .frame(maxWidth: .infinity)
                            .chefGlassCard(cornerRadius: 28, padding: 24)

                            HStack(spacing: 12) {
                                MetricChip(icon: "flame.fill", value: "\(Int(budget.caloriesRemaining))", label: "kcal restantes", tint: .chefPrimary)
                                MetricChip(icon: "bolt.fill", value: "\(Int(max(0, budget.proteinRemaining).rounded()))g", label: "proteína restante", tint: .chefSuccess)
                            }

                            MealsSection(meals: mealsForSelectedDate, fixedMeals: fixedMeals) { slot in
                                Haptics.selection()
                                detailSlot = slot
                            }
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
                .padding()
                .padding(.bottom, 90)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $detailSlot) { slot in
            MealDetailSheet(
                slot: slot,
                meal: mealsForSelectedDate.first { $0.slot == slot },
                dateKey: selectedDateKey,
                dateLabel: isToday ? "hoje" : "em \(dayLabel(selectedDate))"
            )
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }
}

private struct MetricChip: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chefGlassCard()
    }
}

private struct MealsSection: View {
    let meals: [SDMealEntry]
    let fixedMeals: [SDFixedMeal]
    let onSelect: (MealSlot) -> Void

    private static let order: [MealSlot] = [.cafeDaManha, .almoco, .lanche, .posTreino, .jantar, .outro]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refeições")
                .font(.title3.weight(.bold))

            ForEach(Self.order, id: \.self) { slot in
                MealRow(
                    slot: slot,
                    meal: meals.first { $0.slot == slot },
                    planned: fixedMeals.first { $0.slot == slot }
                )
                .onTapGesture { onSelect(slot) }
            }
        }
    }
}

private struct MealRow: View {
    let slot: MealSlot
    let meal: SDMealEntry?
    /// Refeição fixa da dieta amarrada a esse horário (roadmap item 5).
    let planned: SDFixedMeal?

    private var totals: NutritionFacts? {
        guard let meal, !meal.items.isEmpty else { return nil }
        return NutritionEngine.sumNutrition(meal.items.map(\.nutrition))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.label)
                    .font(.subheadline.weight(.semibold))
                if totals != nil {
                    Text(meal?.items.map(\.name).joined(separator: ", ") ?? "")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else if let planned {
                    // Nada registrado, mas a dieta prescreve algo pra esse
                    // horário: mostra o plano em vez de só "nada registrado".
                    Label(planned.items.map(\.name).joined(separator: ", "), systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(Color.chefPrimary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if meal?.photoData != nil {
                Image(systemName: "camera.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let totals {
                Text("\(Int(totals.calories)) kcal · \(totals.protein.formatted(.number.precision(.fractionLength(1))))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(planned == nil ? "Nada registrado" : "Planejado")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .chefGlassCard(cornerRadius: 16, padding: 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    DashboardView()
}
