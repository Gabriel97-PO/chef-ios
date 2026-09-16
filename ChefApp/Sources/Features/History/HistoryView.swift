import SwiftUI
import SwiftData
import Charts
import ChefCore

/// Evolução de consumo e peso (Fase 7 do plano de migração).
struct HistoryView: View {
    @Query(sort: \SDMealEntry.date) private var meals: [SDMealEntry]
    @Query(sort: \SDWeightEntry.date) private var weights: [SDWeightEntry]
    @Query private var profiles: [SDUserProfile]

    private var goal: DailyGoal { profiles.first?.goal ?? DailyGoal(calories: 2000, protein: 150) }
    private var weightEntries: [WeightEntry] { weights.map(\.asWeightEntry) }

    private var consumptionDays: [DayTotalPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let byDate = Dictionary(grouping: meals, by: \.date)

        return (0..<14).reversed().compactMap { offset -> DayTotalPoint? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = DateKey.string(from: day)
            let dayMeals = (byDate[key] ?? []).map(\.asMealEntry)
            let totals = NutritionEngine.sumMeals(dayMeals)
            return DayTotalPoint(date: day, dateKey: key, calories: totals.calories, protein: totals.protein)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if meals.isEmpty && weights.isEmpty {
                        ContentUnavailableView(
                            "Sem histórico ainda",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Registre refeições e peso para ver sua evolução aqui.")
                        )
                        .padding(.top, 60)
                    } else {
                        ConsumptionCard(days: consumptionDays, goal: goal)
                        WeightTrendCard(weights: weights, entries: weightEntries)
                    }
                }
                .padding()
            }
            .navigationTitle("Histórico")
        }
    }
}

private struct DayTotalPoint: Identifiable {
    var id: String { dateKey }
    let date: Date
    let dateKey: String
    let calories: Double
    let protein: Double
}

private struct ConsumptionCard: View {
    let days: [DayTotalPoint]
    let goal: DailyGoal

    private var averageCalories: Double {
        let nonZero = days.filter { $0.calories > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0) { $0 + $1.calories } / Double(nonZero.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consumo (14 dias)").font(.title3.weight(.bold))
                Spacer()
                Text("média \(Int(averageCalories)) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Dia", day.date, unit: .day),
                        y: .value("Calorias", day.calories)
                    )
                    .foregroundStyle(day.calories > goal.calories ? Color.orange : Color.chefPrimary)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Meta", goal.calories))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }

            Text("Linha pontilhada = meta diária de \(Int(goal.calories)) kcal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

private struct WeightTrendCard: View {
    let weights: [SDWeightEntry]
    let entries: [WeightEntry]

    private var average7d: Double? { NutritionEngine.calculateWeightAverage(entries, windowSize: 7) }
    private var change: Double? { NutritionEngine.calculateWeightChange(entries) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Peso").font(.title3.weight(.bold))
                Spacer()
                if let average7d {
                    Text("média 7d: \(average7d.formatted(.number.precision(.fractionLength(1)))) kg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chefPrimary)
                }
            }

            if weights.isEmpty {
                Text("Nenhum peso registrado ainda. Registre em \"Perfil\".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(weights) { entry in
                    LineMark(
                        x: .value("Data", entry.date),
                        y: .value("Peso", entry.weightKg)
                    )
                    .foregroundStyle(Color.chefPrimary)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Data", entry.date),
                        y: .value("Peso", entry.weightKg)
                    )
                    .foregroundStyle(Color.chefPrimary)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .chartYScale(domain: .automatic(includesZero: false))

                if let change {
                    Text(change > 0 ? "+\(change.formatted(.number.precision(.fractionLength(1))))kg desde o primeiro registro" : "\(change.formatted(.number.precision(.fractionLength(1))))kg desde o primeiro registro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

#Preview {
    HistoryView()
}
