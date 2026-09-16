import SwiftUI
import ChefCore

/// Tela "Hoje" — responde "como está meu dia?" com hierarquia visual clara
/// (seção 7 do plano de migração). Dados fixos de demonstração nesta
/// primeira versão; a Fase 3 troca por SwiftData + estado real do app.
struct DashboardView: View {
    private let goal = DailyGoal(calories: 2100, protein: 170)
    private let consumed = NutritionFacts(calories: 912, protein: 34.2, carbs: 40, fat: 20)

    private var budget: NutritionEngine.RemainingBudget {
        NutritionEngine.calculateRemainingBudget(goal: goal, consumed: consumed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Boa tarde")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Gabriel")
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
                            Text("\(consumed.protein, specifier: "%.1f") / \(Int(goal.protein)) g")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 28))

                    HStack(spacing: 12) {
                        MetricChip(icon: "flame.fill", value: "\(Int(budget.caloriesRemaining))", label: "kcal restantes", tint: .orange)
                        MetricChip(icon: "bolt.fill", value: "\(Int(max(0, budget.proteinRemaining)))g", label: "proteína restante", tint: .green)
                    }
                }
                .padding()
            }
            .navigationTitle("Hoje")
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

#Preview {
    DashboardView()
}
