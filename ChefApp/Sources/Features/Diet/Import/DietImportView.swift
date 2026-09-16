import SwiftUI
import SwiftData
import ChefCore

private enum ImportStage {
    case input, processing, review, applied
}

/// Importação de dieta profissional (Fase 6 do plano de migração — CNP).
/// Nunca aplica a dieta silenciosamente: sempre passa por uma tela de
/// revisão antes, mostrando ambiguidades e alimentos sem correspondência
/// na base local — "não encontrado ≠ zero ≠ estimado ≠ inventado".
struct DietImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var stage: ImportStage = .input
    @State private var text = ""
    @State private var errorMessage: String?
    @State private var result: CnpImportResult?
    @State private var unmatched: [String] = []
    @State private var checklistStep = 0
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 32

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch stage {
                    case .input: inputStage
                    case .processing: processingStage
                    case .review: if let result { reviewStage(result) }
                    case .applied: appliedStage
                    }
                }
                .padding()
            }
            .navigationTitle("Importar dieta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Etapa 1: colar o texto

    private var inputStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.fill").font(.largeTitle).foregroundStyle(.secondary)
                Text("Cole abaixo o texto da sua dieta (ou um documento no formato Chef Nutrition Protocol) e o Chef organiza tudo para você.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("PDF/DOCX ainda não são lidos automaticamente nesta versão — cole o texto extraído dele abaixo.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .chefGlassCard(cornerRadius: 20, padding: 20)

            TextEditor(text: $text)
                .frame(height: 220)
                .padding(8)
                .background(.thinMaterial, in: .rect(cornerRadius: 16))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("PACIENTE: Gabriel\n\nCALORIAS: 2100\nPROTEÍNA: 170\n\nALMOÇO\n150 g arroz\n200 g peito de frango\nOU\n200 g batata doce")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            Button {
                analyze()
            } label: {
                Text("Analisar dieta").font(.headline).frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.chefPrimary)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Etapa 2: "processando"

    private var processingStage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lendo sua dieta…").font(.headline)
            checklistRow("Encontramos sua meta calórica", done: checklistStep >= 1)
            checklistRow("Encontramos sua meta proteica", done: checklistStep >= 2)
            checklistRow("Identificamos suas refeições", done: checklistStep >= 3)
            checklistRow("Organizamos os alimentos e substituições", done: checklistStep >= 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func checklistRow(_ label: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.chefSuccess : .secondary)
            Text(label).foregroundStyle(done ? .primary : .secondary)
        }
    }

    // MARK: - Etapa 3: revisão

    private func reviewStage(_ result: CnpImportResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                Text("Sua dieta foi encontrada").font(.subheadline).foregroundStyle(.secondary)
                Text("\(Int(result.document.goals.calories)) kcal").font(.system(size: heroSize, weight: .black, design: .rounded))
                Text("\(Int(result.document.goals.proteinG))g proteína").font(.headline).foregroundStyle(Color.chefSuccess)
                HStack(spacing: 16) {
                    Text("\(result.summary.mealCount) refeições")
                    Text("\(result.summary.foodCount) alimentos")
                    Text("\(result.summary.substitutionCount) substituições")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .chefGlassCard(cornerRadius: 20, padding: 20)

            if !result.summary.foundCalorieGoal || !result.summary.foundProteinGoal {
                warningBox("Não encontramos \(!result.summary.foundCalorieGoal ? "a meta calórica" : "")\(!result.summary.foundCalorieGoal && !result.summary.foundProteinGoal ? " nem " : "")\(!result.summary.foundProteinGoal ? "a meta proteica" : "") no texto. Você pode ajustar depois em \"Dieta\".")
            }

            if !result.summary.ambiguities.isEmpty {
                warningBox("Precisa de revisão:\n" + result.summary.ambiguities.prefix(6).map { "• \($0)" }.joined(separator: "\n"))
            }

            if !unmatched.isEmpty {
                Text("Sem informação nutricional ainda: \(unmatched.joined(separator: ", ")) — serão adicionados às refeições fixas, mas você precisa cadastrar os valores nutricionais deles manualmente em \"Registrar\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
            }

            ForEach(result.document.meals, id: \.name) { meal in
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name).font(.subheadline.weight(.semibold))
                    Text(meal.foods.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let substitutions = meal.substitutions, !substitutions.isEmpty {
                        Text(substitutions.map { $0.options.map(\.name).joined(separator: " ou ") }.joined(separator: " · ") + " — usamos \"\(substitutions[0].options[0].name)\" como padrão; troque depois se preferir.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: .rect(cornerRadius: 12))
            }

            HStack(spacing: 10) {
                Button("Revisar texto") { stage = .input }
                    .buttonStyle(.bordered)
                Button("Aplicar dieta") { applyDiet(result) }
                    .buttonStyle(.borderedProminent)
                    .tint(.chefPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func warningBox(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }

    // MARK: - Etapa 4: aplicado

    private var appliedStage: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Color.chefSuccess)
            Text("Dieta aplicada").font(.title2.weight(.bold))
            Text("Sua meta e suas refeições fixas foram atualizadas. Você pode revisar tudo em \"Dieta\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Ver minha dieta") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.chefPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Ações

    private func analyze() {
        errorMessage = nil
        stage = .processing
        checklistStep = 0

        let parsed = CNPTextParser.parse(text: text)
        let unmatchedFoods = DietImportService.previewUnmatchedFoods(parsed.document, in: context)

        Task {
            for step in 1...4 {
                try? await Task.sleep(for: .milliseconds(420))
                checklistStep = step
            }
            result = parsed
            unmatched = unmatchedFoods
            stage = .review
        }
    }

    private func applyDiet(_ result: CnpImportResult) {
        _ = DietImportService.apply(result, label: result.document.patient.name.isEmpty ? "Dieta importada" : result.document.patient.name, in: context)
        Haptics.success()
        stage = .applied
    }
}

#Preview {
    DietImportView()
}
