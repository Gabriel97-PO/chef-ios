import SwiftUI
import SwiftData
import Charts
import ChefCore

/// Telas de detalhe abertas a partir dos cards do Histórico (e do card de
/// peso no Perfil) — antes os cards eram só ilustrativos, sem nenhuma ação.

struct ConsumptionHistoryDetailView: View {
    @Query(sort: \SDMealEntry.date) private var meals: [SDMealEntry]
    @Query private var profiles: [SDUserProfile]

    private var goal: DailyGoal { profiles.first?.goal ?? DailyGoal(calories: 2000, protein: 150) }

    private var days: [ConsumptionDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let byDate = Dictionary(grouping: meals, by: \.date)

        return (0..<30).reversed().compactMap { offset -> ConsumptionDay? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = DateKey.string(from: day)
            let dayMeals = (byDate[key] ?? []).map(\.asMealEntry)
            let totals = NutritionEngine.sumMeals(dayMeals)
            return ConsumptionDay(date: day, dateKey: key, calories: totals.calories, protein: totals.protein)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Chart {
                    ForEach(days) { day in
                        BarMark(
                            x: .value("Dia", day.date, unit: .day),
                            y: .value("Calorias", day.calories)
                        )
                        .foregroundStyle(day.calories > goal.calories ? Color.orange : Color.chefPrimary)
                        .cornerRadius(3)
                    }
                    RuleMark(y: .value("Meta", goal.calories))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
                .chefGlassCard(cornerRadius: 20, padding: 16)

                Text("Últimos 30 dias")
                    .font(.title3.weight(.bold))

                VStack(spacing: 8) {
                    ForEach(days.reversed()) { day in
                        dayRow(day)
                    }
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .navigationTitle("Consumo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayRow(_ day: ConsumptionDay) -> some View {
        HStack {
            Text(day.date.formatted(.dateTime.day().month(.abbreviated).weekday(.abbreviated)))
                .font(.subheadline.weight(.semibold))
                .frame(width: 110, alignment: .leading)
            Spacer()
            if day.calories > 0 {
                Text("\(Int(day.calories)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(day.calories > goal.calories ? .orange : .primary)
                Text("· \(day.protein.formatted(.number.precision(.fractionLength(1))))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sem registro")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .chefGlassCard(cornerRadius: 14, padding: 12)
    }
}

private struct ConsumptionDay: Identifiable {
    var id: String { dateKey }
    let date: Date
    let dateKey: String
    let calories: Double
    let protein: Double
}

struct WeightHistoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SDWeightEntry.date, order: .reverse) private var weights: [SDWeightEntry]

    private var entries: [WeightEntry] { weights.map(\.asWeightEntry) }
    private var average7d: Double? { NutritionEngine.calculateWeightAverage(entries, windowSize: 7) }
    private var change: Double? { NutritionEngine.calculateWeightChange(entries) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if weights.isEmpty {
                    ContentUnavailableView(
                        "Nenhum peso registrado",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Registre seu peso no Perfil pra acompanhar a evolução aqui.")
                    )
                    .padding(.top, 60)
                } else {
                    HStack(spacing: 16) {
                        stat(label: "atual", value: weights.first?.weightKg)
                        stat(label: "média 7d", value: average7d, tint: .chefPrimary)
                        stat(label: "variação total", value: change, signed: true)
                    }
                    .chefGlassCard(cornerRadius: 20, padding: 16)

                    Chart(weights.sorted { $0.date < $1.date }) { entry in
                        LineMark(x: .value("Data", entry.date), y: .value("Peso", entry.weightKg))
                            .foregroundStyle(Color.chefPrimary)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Data", entry.date), y: .value("Peso", entry.weightKg))
                            .foregroundStyle(Color.chefPrimary)
                    }
                    .frame(height: 200)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chefGlassCard(cornerRadius: 20, padding: 16)

                    Text("Todos os registros")
                        .font(.title3.weight(.bold))

                    VStack(spacing: 10) {
                        ForEach(weights) { entry in
                            HStack {
                                Text(formattedDate(entry.date))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(entry.weightKg.formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.chefPrimary)
                                Button {
                                    delete(entry)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chefGlassCard(cornerRadius: 14, padding: 12)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .navigationTitle("Peso")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedDate(_ key: String) -> String {
        guard let date = DateKey.date(from: key) else { return key }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func delete(_ entry: SDWeightEntry) {
        Haptics.selection()
        context.delete(entry)
        try? context.save()
    }

    @ViewBuilder
    private func stat(label: String, value: Double?, tint: Color = .primary, signed: Bool = false) -> some View {
        VStack(spacing: 2) {
            if let value {
                Text((signed && value > 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(1))))
                    .font(.headline)
                    .foregroundStyle(tint)
            } else {
                Text("—").font(.headline).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: .rect(cornerRadius: 10))
    }
}
