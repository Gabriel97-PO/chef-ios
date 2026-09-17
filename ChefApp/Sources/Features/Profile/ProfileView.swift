import SwiftUI
import SwiftData
import ChefCore

/// Perfil: nome, peso com média de 7 dias e disclaimer (seções 16 e 24 do
/// briefing original / Fase 7 do plano de migração).
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SDUserProfile]
    @Query(sort: \SDWeightEntry.date) private var weights: [SDWeightEntry]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChefHeader(title: "Perfil")

                    if let profile = profiles.first {
                        NameCard(profile: profile)
                    }
                    WeightCard(weights: weights)
                    AppleHealthCard()
                    MealRemindersCard()
                    AboutCard()
                }
                .padding()
                .padding(.bottom, 90)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct NameCard: View {
    @Bindable var profile: SDUserProfile
    @Environment(\.modelContext) private var context
    @State private var editing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Nome").font(.caption).foregroundStyle(.secondary)
                if editing {
                    TextField("Nome", text: $profile.name)
                        .font(.title3.weight(.bold))
                        .onSubmit { editing = false; try? context.save() }
                } else {
                    Text(profile.name).font(.title3.weight(.bold))
                }
            }
            Spacer()
            Button(editing ? "OK" : "Editar") {
                editing.toggle()
                if !editing { try? context.save() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.chefPrimary)
        }
        .chefGlassCard()
    }
}

private struct WeightCard: View {
    let weights: [SDWeightEntry]
    @Environment(\.modelContext) private var context
    @State private var input = ""
    @State private var logged = false

    private var entries: [WeightEntry] { weights.map(\.asWeightEntry) }
    private var latest: Double? { weights.last?.weightKg }
    private var average7d: Double? { NutritionEngine.calculateWeightAverage(entries, windowSize: 7) }
    private var change: Double? { NutritionEngine.calculateWeightChange(entries) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                WeightHistoryDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Meu peso").font(.title3.weight(.bold))
                        Spacer()
                        Text("Ver histórico")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.chefPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)

                    HStack(spacing: 10) {
                        stat(label: "atual (kg)", value: latest)
                        stat(label: "média 7d (kg)", value: average7d, tint: .chefPrimary)
                        stat(label: "desde o início", value: change, signed: true)
                    }

                    if !weights.isEmpty {
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(weights.suffix(14)) { entry in
                                Capsule()
                                    .fill(Color.chefPrimary.gradient)
                                    .frame(width: 8, height: barHeight(for: entry.weightKg))
                            }
                        }
                        .frame(height: 50, alignment: .bottom)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weights.map(\.weightKg))
                    }
                }
            }
            .buttonStyle(.plain)

            HStack {
                TextField("Peso de hoje (kg)", text: $input)
                    .keyboardType(.decimalPad)
                    .padding(10)
                    .background(.thinMaterial, in: .rect(cornerRadius: 10))
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        logWeight()
                    }
                } label: {
                    Text(logged ? "✓" : "Registrar")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(logged ? Color.chefSuccess : Color.chefPrimary, in: .rect(cornerRadius: 10))
                        .foregroundStyle(Color.chefOnPrimary)
                }
            }
        }
        .chefGlassCard()
        .onAppear {
            if let latest { input = latest.formatted(.number.precision(.fractionLength(1))) }
        }
    }

    private func barHeight(for weight: Double) -> Double {
        let values = weights.map(\.weightKg)
        guard let min = values.min(), let max = values.max(), max > min else { return 24 }
        let pct = (weight - min) / (max - min)
        return 8 + pct * 36
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

    private func logWeight() {
        guard let value = Double(input.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
        WeightStore.logToday(value, dateKey: DateKey.today(), in: context)
        Haptics.success()
        logged = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            logged = false
        }
    }
}

private struct AboutCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sobre o Chef").font(.title3.weight(.bold))
            Text("O Chef é uma ferramenta de acompanhamento alimentar baseada nos dados que você registra e na sua meta diária de calorias e proteína. Ele não é um aplicativo médico ou de nutrição clínica, não diagnostica condições de saúde e não recomenda ou altera doses de medicamentos. Use-o como apoio para entender seu consumo, não como substituto de orientação profissional.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .chefGlassCard()
    }
}

#Preview {
    ProfileView()
}
