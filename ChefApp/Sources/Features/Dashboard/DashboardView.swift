import SwiftUI
import SwiftData
import ChefCore

/// Tela "Hoje" — responde "como está meu dia?" com hierarquia visual clara
/// (seção 7 do plano de migração). Lê dados reais do SwiftData agora —
/// nada mais fixo como na primeira versão da Fase 1.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SDUserProfile]
    @Query private var meals: [SDMealEntry]

    private var profile: SDUserProfile? { profiles.first }
    private let today = DateKey.today()

    private var todaysMeals: [SDMealEntry] {
        meals.filter { $0.date == today }
    }

    private var consumed: NutritionFacts {
        NutritionEngine.sumMeals(todaysMeals.map(\.asMealEntry))
    }

    private var budget: NutritionEngine.RemainingBudget? {
        guard let goal = profile?.goal else { return nil }
        return NutritionEngine.calculateRemainingBudget(goal: goal, consumed: consumed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile, let budget {
                    let goal = profile.goal
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(profile.name)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                        }

                        VStack(spacing: 6) {
                            Text("\(Int(consumed.calories))")
                                .font(.system(size: 64, weight: .black, design: .rounded))
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
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 28))

                        HStack(spacing: 12) {
                            MetricChip(icon: "flame.fill", value: "\(Int(budget.caloriesRemaining))", label: "kcal restantes", tint: .chefPrimary)
                            MetricChip(icon: "bolt.fill", value: "\(Int(max(0, budget.proteinRemaining).rounded()))g", label: "proteína restante", tint: .chefSuccess)
                        }

                        MealsSection(meals: todaysMeals)
                    }
                    .padding()
                } else {
                    ProgressView()
                        .padding(.top, 100)
                }
            }
            .navigationTitle("Hoje")
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case ..<12: return "Bom dia"
        case ..<18: return "Boa tarde"
        default: return "Boa noite"
        }
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
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

private struct MealsSection: View {
    let meals: [SDMealEntry]

    private static let order: [MealSlot] = [.cafeDaManha, .almoco, .lanche, .posTreino, .jantar, .outro]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refeições")
                .font(.title3.weight(.bold))

            ForEach(Self.order, id: \.self) { slot in
                let meal = meals.first { $0.slot == slot }
                MealRow(slot: slot, meal: meal)
            }
        }
    }
}

private struct MealRow: View {
    let slot: MealSlot
    let meal: SDMealEntry?

    private var totals: NutritionFacts? {
        guard let meal, !meal.items.isEmpty else { return nil }
        return NutritionEngine.sumNutrition(meal.items.map(\.nutrition))
    }

    var body: some View {
        HStack {
            Text(slot.label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let totals {
                Text("\(Int(totals.calories)) kcal · \(totals.protein.formatted(.number.precision(.fractionLength(1))))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nada registrado")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

#Preview {
    DashboardView()
}
