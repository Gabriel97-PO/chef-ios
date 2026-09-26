import SwiftUI

/// Tela pra comparar a splash nos dois temas e com "reduzir movimento"
/// simulado, sem precisar reiniciar o app nem trocar o ajuste do sistema a
/// cada teste. Existe porque não há Xcode local pra usar o canvas de
/// preview (2017 MacBook Pro sem suporte oficial) — essa é a forma de
/// testar de verdade, dentro do próprio app instalado por sideload.
struct ChefLoadingPreviewView: View {
    @State private var colorSchemeOverride: ColorScheme = .light
    @State private var forceReduceMotion = false
    @State private var speedMultiplier: Double = 1.0
    @State private var runID = UUID()

    var body: some View {
        VStack(spacing: 20) {
            ChefLoadingView(onFinished: {}, forceReduceMotion: forceReduceMotion, speedMultiplier: speedMultiplier)
                .id(runID)
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.separator, lineWidth: 1))
                .padding(.horizontal)

            Picker("Tema", selection: $colorSchemeOverride) {
                Text("Claro").tag(ColorScheme.light)
                Text("Escuro").tag(ColorScheme.dark)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: colorSchemeOverride) { _, _ in runID = UUID() }

            Picker("Velocidade", selection: $speedMultiplier) {
                Text("0,25x").tag(0.25)
                Text("0,5x").tag(0.5)
                Text("1x").tag(1.0)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: speedMultiplier) { _, _ in runID = UUID() }

            Toggle("Simular \"Reduzir movimento\"", isOn: $forceReduceMotion)
                .padding(.horizontal)
                .onChange(of: forceReduceMotion) { _, _ in runID = UUID() }

            Button {
                Haptics.selection()
                runID = UUID()
            } label: {
                Label("Repetir", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(Color.chefOnPrimary)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.chefPrimary)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Pré-visualizar splash")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(colorSchemeOverride)
    }
}

#Preview {
    NavigationStack { ChefLoadingPreviewView() }
}
