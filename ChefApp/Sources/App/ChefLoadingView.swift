import SwiftUI

/// Tela de loading no lançamento do app, seguindo as 6 fases descritas no
/// fluxo de marca: início (ícone estático) → ativação (a folha ganha vida)
/// → transição (elementos se expandem) → progresso (indicador circular
/// animado) → conclusão (ícone retorna com feedback) → feedback (micro
/// feedback visual). Chama `onFinished` ao final pra revelar o app.
struct ChefLoadingView: View {
    var onFinished: () -> Void

    @State private var leafGlow: Double = 0
    @State private var markScale: CGFloat = 1
    @State private var particlesVisible = false
    @State private var showRing = false
    @State private var ringTrim: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var showCheck = false
    @State private var checkScale: CGFloat = 0.3
    @State private var markOpacity: Double = 1

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            ZStack {
                if particlesVisible {
                    ForEach(0..<8, id: \.self) { index in
                        ChefLoadingParticle(index: index)
                    }
                }

                if showRing {
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 184, height: 184)
                        .rotationEffect(.degrees(ringRotation))
                }

                ChefMarkView(hatColor: .primary, accentColor: .chefPrimary)
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.chefPrimary.opacity(leafGlow), radius: 26)
                    .scaleEffect(markScale)

                if showCheck {
                    Circle()
                        .fill(Color.chefSuccess)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .scaleEffect(checkScale)
                        .offset(x: 52, y: 54)
                }
            }
            .opacity(markOpacity)

            VStack {
                Spacer()
                Text("CHEF")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(6)
                    .foregroundStyle(.secondary)
                    .opacity(markOpacity * 0.7)
                    .padding(.bottom, 64)
            }
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        // 1 · início — ícone estático.
        try? await sleep(500)

        // 2 · ativação — a folha ganha vida (glow + leve bounce de escala).
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            markScale = 1.14
            leafGlow = 0.7
        }
        try? await sleep(180)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            markScale = 1.0
        }
        try? await sleep(320)

        // 3 · transição — elementos se expandem (partículas irradiando).
        Haptics.selection()
        withAnimation(.easeOut(duration: 0.1)) { particlesVisible = true }
        try? await sleep(500)

        // 4 · progresso — indicador circular animado.
        withAnimation(.easeIn(duration: 0.2)) {
            showRing = true
            ringTrim = 0.72
        }
        withAnimation(.linear(duration: 0.9)) {
            ringRotation = 360
        }
        try? await sleep(900)

        // 5 · conclusão — ícone retorna com feedback (check).
        particlesVisible = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            ringTrim = 1.0
        }
        try? await sleep(150)
        withAnimation(.easeOut(duration: 0.25)) { showRing = false }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showCheck = true
            checkScale = 1.0
        }
        Haptics.success()
        try? await sleep(500)

        // 6 · feedback — micro feedback visual, depois revela o app.
        withAnimation(.easeInOut(duration: 0.35)) {
            markOpacity = 0
        }
        try? await sleep(350)
        onFinished()
    }

    private func sleep(_ ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }
}

private struct ChefLoadingParticle: View {
    let index: Int
    @State private var animate = false

    private var angle: Double { Double(index) / 8 * 360 }

    var body: some View {
        Circle()
            .fill(Color.chefPrimary)
            .frame(width: 6, height: 6)
            .offset(
                x: animate ? cos(angle * .pi / 180) * 96 : 0,
                y: animate ? sin(angle * .pi / 180) * 96 : 0
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.03)) {
                    animate = true
                }
            }
    }
}

#Preview {
    ChefLoadingView(onFinished: {})
}
