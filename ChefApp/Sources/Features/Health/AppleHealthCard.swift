import SwiftUI
import SwiftData
import ChefCore

/// Conexão com o Apple Saúde (roadmap itens 2 e 3).
struct AppleHealthCard: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SDUserProfile]
    @Query private var meals: [SDMealEntry]

    @State private var status: Status = .idle
    @State private var bodyFat: Double?

    private enum Status: Equatable {
        case idle
        case working
        case imported(Int)
        case exported
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Saúde", systemImage: "heart.fill")
                .font(.title3.weight(.bold))

            Text("Importa o peso que sua balança já manda pro Apple Saúde — inclusive balança de bioimpedância — e exporta o que você consumiu no Chef.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let bodyFat {
                Label("Gordura corporal medida: \(bodyFat.formatted(.number.precision(.fractionLength(1))))%", systemImage: "figure.stand")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chefPrimary)
            }

            switch status {
            case .working:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Conversando com o Apple Saúde…").font(.caption)
                }
            case .imported(let count):
                Label(
                    count == 0
                        ? "Nenhum peso novo pra importar — o Chef já está em dia."
                        : "\(count) \(count == 1 ? "dia importado" : "dias importados") da sua balança.",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(Color.chefSuccess)
            case .exported:
                Label("Consumo de hoje exportado pro Apple Saúde.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.chefSuccess)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Não foi possível conectar", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("O acesso ao Apple Saúde exige uma conta paga do Apple Developer Program. Num app instalado por sideload com Apple ID gratuito, a Apple bloqueia essa permissão.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 10))
            case .idle:
                EmptyView()
            }

            HStack(spacing: 10) {
                Button {
                    Task { await importWeights() }
                } label: {
                    Label("Importar peso", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.chefOnPrimary)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.chefPrimary)

                Button {
                    Task { await exportToday() }
                } label: {
                    Label("Exportar consumo", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
            }
            .disabled(status == .working || !HealthKitService.isAvailable)
        }
        .chefGlassCard()
    }

    private func importWeights() async {
        status = .working
        do {
            try await HealthKitService.requestAuthorization()
            let count = try await HealthKitService.importWeights(into: context)
            bodyFat = try? await HealthKitService.latestBodyFatPercentage()
            Haptics.success()
            status = .imported(count)
        } catch {
            Haptics.error()
            status = .failed(error.localizedDescription)
        }
    }

    private func exportToday() async {
        status = .working
        let today = DateKey.today()
        let consumed = NutritionEngine.sumMeals(
            meals.filter { $0.date == today }.map(\.asMealEntry)
        )
        do {
            try await HealthKitService.requestAuthorization()
            try await HealthKitService.exportConsumption(
                consumed,
                waterMl: nil,
                on: today
            )
            Haptics.success()
            status = .exported
        } catch {
            Haptics.error()
            status = .failed(error.localizedDescription)
        }
    }
}
