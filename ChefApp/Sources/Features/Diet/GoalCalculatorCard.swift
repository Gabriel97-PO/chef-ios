import SwiftUI
import SwiftData
import ChefCore

/// Calcula a meta diária a partir do metabolismo basal (roadmap itens 6 e 8).
///
/// Duas regras que valem pra todo o app e aparecem aqui:
/// 1. A estimativa nunca se aplica sozinha. O usuário vê o número e decide
///    usar — o mesmo princípio do import de dieta, que nunca aplica nada
///    silenciosamente.
/// 2. Dieta prescrita por profissional ganha da estimativa. Se existe uma
///    dieta CNP ativa, avisamos antes de sobrescrever a prescrição.
struct GoalCalculatorCard: View {
    @Bindable var profile: SDUserProfile
    let currentWeightKg: Double?
    let hasActiveDiet: Bool

    @Environment(\.modelContext) private var context
    @State private var applied = false

    private var metrics: BodyMetrics? { profile.bodyMetrics(currentWeightKg: currentWeightKg) }
    private var targets: EnergyTargets? { metrics.flatMap(EnergyEngine.calculateTargets) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            bodySection

            if let targets {
                Divider()
                resultSection(targets)
            } else {
                Divider()
                Label(missingDataMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chefGlassCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Medidas

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Seu corpo", systemImage: "figure.stand")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                readOnlyField(
                    label: "Peso atual (kg)",
                    value: currentWeightKg.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—",
                    hint: "vem do Perfil"
                )
                optionalNumberField(label: "Altura (cm)", value: $profile.heightCm, range: 100...250)
                optionalIntField(label: "Idade", value: $profile.age, range: 10...110)
            }

            picker("Sexo", selection: Binding(get: { profile.sex }, set: { profile.sex = $0; save() }), options: BiologicalSex.allCases) { $0.label }

            VStack(alignment: .leading, spacing: 4) {
                picker("Atividade", selection: Binding(get: { profile.activity }, set: { profile.activity = $0; save() }), options: ActivityLevel.allCases) { $0.label }
                Text(profile.activity.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            picker("Objetivo", selection: Binding(get: { profile.objective }, set: { profile.objective = $0; save() }), options: WeightObjective.allCases) { $0.label }
        }
    }

    // MARK: - Resultado

    private func resultSection(_ targets: EnergyTargets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sua estimativa", systemImage: "flame.fill")
                .font(.title3.weight(.bold))

            HStack(spacing: 10) {
                energyStat(
                    value: targets.basalMetabolicRate,
                    label: "metabolismo basal",
                    detail: "em repouso"
                )
                energyStat(
                    value: targets.totalEnergyExpenditure,
                    label: "gasto total",
                    detail: profile.activity.label.lowercased()
                )
                energyStat(
                    value: targets.calories,
                    label: "meta sugerida",
                    detail: profile.objective.label.lowercased(),
                    tint: .chefPrimary
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                suggestionRow(icon: "bolt.fill", label: "Proteína", value: "\(Int(targets.protein)) g", tint: .chefSuccess)
                suggestionRow(icon: "leaf.fill", label: "Carboidratos", value: "\(Int(targets.carbs)) g")
                suggestionRow(icon: "drop.fill", label: "Gorduras", value: "\(Int(targets.fat)) g")
                suggestionRow(icon: "circle.grid.cross.fill", label: "Fibras", value: "\(Int(targets.fiber)) g")
                suggestionRow(icon: "drop.halffull", label: "Água", value: "\(Int(targets.water)) ml")
            }

            if hasActiveDiet {
                Label("Você tem uma dieta prescrita ativa. Aplicar a estimativa vai substituir as metas dela.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 10))
            }

            Button {
                apply(targets)
            } label: {
                Label(applied ? "Metas atualizadas" : "Usar estas metas", systemImage: applied ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(applied ? Color.chefSuccess : Color.chefPrimary)

            Text("Estimativa populacional (Mifflin-St Jeor), não prescrição. Ajuste os valores abaixo se sua nutricionista indicou outros.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var missingDataMessage: String {
        if currentWeightKg == nil {
            return "Registre seu peso no Perfil para calcularmos sua meta automaticamente."
        }
        return "Preencha altura e idade para calcularmos sua meta a partir do seu metabolismo basal."
    }

    // MARK: - Componentes

    private func energyStat(value: Double, label: String, detail: String, tint: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }

    private func suggestionRow(icon: String, label: String, value: String, tint: Color = .secondary) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
        }
    }

    private func readOnlyField(label: String, value: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(hint).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }

    private func optionalNumberField(label: String, value: Binding<Double?>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("—", text: Binding(
                get: { value.wrappedValue.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "" },
                set: { raw in
                    let parsed = Double(raw.replacingOccurrences(of: ",", with: "."))
                    value.wrappedValue = parsed.map { min(max($0, range.lowerBound), range.upperBound) }
                    save()
                }
            ))
            .keyboardType(.numberPad)
            .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }

    private func optionalIntField(label: String, value: Binding<Int?>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("—", text: Binding(
                get: { value.wrappedValue.map(String.init) ?? "" },
                set: { raw in
                    value.wrappedValue = Int(raw).map { min(max($0, range.lowerBound), range.upperBound) }
                    save()
                }
            ))
            .keyboardType(.numberPad)
            .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }

    private func picker<T: Hashable & Identifiable>(
        _ label: String,
        selection: Binding<T>,
        options: [T],
        title: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(options) { option in
                    Text(title(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.chefPrimary)
        }
    }

    // MARK: - Ações

    private func apply(_ targets: EnergyTargets) {
        profile.goal = targets.asDailyGoal
        save()
        Haptics.success()
        applied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            applied = false
        }
    }

    private func save() {
        try? context.save()
    }
}
