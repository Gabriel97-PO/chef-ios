import SwiftUI

/// Tela de loading no lançamento do app, seguindo a especificação de 6
/// estados do fluxo de marca (18/set/2026): Início → Ativação → Transição
/// → Progresso → Conclusão → Feedback. Chama `onFinished` ao final pra
/// revelar o app.
///
/// O que foi implementado da especificação e o que não se aplica a este
/// app (nativo iOS, 100% local, sem rede):
/// - Estados 1-6, tempos e curvas da tabela (AC.01-04, AC.07-08): sim.
/// - Só a folha/faixa animam no estado 2, o chapéu fica parado (AC.03):
///   sim — por isso `ChefHatShape` é renderizado à parte de
///   `ChefStripeShape`/`ChefLeafShape` aqui, em vez de compor tudo numa
///   marca única e indivisível.
/// - Único acento por tema, sem degradê no acento (RN.10): sim — o anel
///   de progresso é cor chapada.
/// - "Reduzir movimento" (AC.10): sim, via `accessibilityReduceMotion`.
/// - Não roda a sequência completa ao voltar de segundo plano (RN.02):
///   sim, de graça — `AppRootView` mantém `showSplash = false` durante
///   toda a vida do processo, e SwiftUI não recria a view ao só voltar do
///   background.
/// - Não pode ser pulada por toque (RN.15): sim — não tem gesto nenhum
///   aqui.
/// - Estado 4 condicional a carregamento real (RN.05/06/RN.14): a lógica
///   existe (`dataAlreadyReady`), mas como todo dado do Chef é local e já
///   carrega no `init()` do App antes da UI existir, ela nunca dispara na
///   prática hoje — fica pronta pra quando um carregamento de verdade
///   reaproveitar esse componente.
/// - Lottie/Rive, ícone adaptativo Android, exportação SVG web, telas de
///   erro/cache/timeout de rede (RN.08/09, AC.12/13): fora de escopo — o
///   Chef não tem rede nem backend, essas regras existem pra um app que
///   ainda não é este.
struct ChefLoadingView: View {
    var onFinished: () -> Void
    /// Só pra tela de preview: simula "reduzir movimento" sem precisar
    /// trocar o ajuste do sistema pra comparar as duas versões.
    var forceReduceMotion = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { forceReduceMotion || systemReduceMotion }

    @State private var leafScale: CGFloat = ChefLoadingConfig.introStartScale
    @State private var leafRotation: Double = 0
    @State private var leafGlow: Double = 0
    @State private var particlesVisible = false
    @State private var showRing = false
    @State private var ringTrim: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var showCheck = false
    @State private var checkScale: CGFloat = 0.3
    @State private var showFeedbackStrokes = false
    @State private var markOpacity: Double = 1

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
                .opacity(markOpacity)

            ZStack {
                if particlesVisible {
                    ForEach(0..<ChefLoadingConfig.particleCount, id: \.self) { index in
                        ChefLoadingParticle(index: index, total: ChefLoadingConfig.particleCount)
                    }
                }

                if showRing {
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: ChefLoadingConfig.ringLineWidth, lineCap: .round))
                        .frame(width: ChefLoadingConfig.ringDiameter, height: ChefLoadingConfig.ringDiameter)
                        .rotationEffect(.degrees(ringRotation))
                }

                // Chapéu sempre parado — só a faixa/folha animam (AC.03).
                // Contorno na cor de marca (não mais um cinza sutil) pra
                // bater com o ícone real (18/set/2026): o chapéu inteiro
                // tem a silhueta contornada em laranja/Volt Green, não só
                // a faixa e a folha. `ChefHatShape` é um path composto com
                // subpaths sobrepostos (corpo + coroa + pontas) — dar
                // `.stroke` nele direto desenharia costura visível em cada
                // sobreposição, porque stroke traça cada subpath
                // isoladamente. Preenchimento, ao contrário, funde
                // sobreposições pela regra de enchimento (nonZero) sem
                // costura — por isso o contorno aqui é construído com dois
                // preenchimentos empilhados (cópia maior na cor de marca
                // atrás, cópia no tamanho real por cima) em vez de stroke.
                ZStack {
                    ChefHatShape()
                        .scale(1.055)
                        .fill(Color.chefPrimary)
                    ChefHatShape()
                        .fill(Color.chefFigure)
                }
                .frame(width: ChefLoadingConfig.markSize, height: ChefLoadingConfig.markSize)

                ZStack {
                    ChefStripeShape().fill(Color.chefPrimary)
                    // A folha é um contorno oco no ícone real, não uma
                    // mancha sólida — e, diferente do chapéu, o path dela
                    // é um polígono único fechado (sem subpaths
                    // sobrepostos), então dá pra usar `.stroke` direto
                    // sem costura.
                    ChefLeafShape()
                        .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                .frame(width: ChefLoadingConfig.markSize, height: ChefLoadingConfig.markSize)
                .shadow(color: Color.chefPrimary.opacity(leafGlow), radius: 20)
                .scaleEffect(leafScale)
                // Ancorado perto da base da folha (onde ela "nasce" do
                // chapéu), não no centro — assim a rotação lê como um talo
                // balançando, não a folha inteira girando no lugar.
                .rotationEffect(.degrees(leafRotation), anchor: UnitPoint(x: 0.70, y: 0.91))

                if showFeedbackStrokes {
                    ChefFeedbackStrokes()
                        .frame(width: ChefLoadingConfig.markSize, height: ChefLoadingConfig.markSize)
                }

                if showCheck {
                    Circle()
                        .fill(Color.chefSuccess)
                        .frame(width: ChefLoadingConfig.checkBadgeDiameter, height: ChefLoadingConfig.checkBadgeDiameter)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .scaleEffect(checkScale)
                        .offset(x: ChefLoadingConfig.checkBadgeOffset.x, y: ChefLoadingConfig.checkBadgeOffset.y)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showCheck ? "Pronto" : "Carregando")
        .task { await runSequence() }
    }

    private func runSequence() async {
        // 1 · início — ícone estático em repouso.
        try? await sleep(ChefLoadingConfig.stage1IntroMs)

        // 2 · ativação — a folha ganha vida: escala de 0.92 pra 1.0, brilho
        // do acento, e um ciclo só de rotação (-8°→0°, spring) — acorda e
        // assenta, não fica balançando o resto da splash. O chapéu
        // permanece parado o tempo todo (AC.03).
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { leafScale = 1.0; leafGlow = 0.55 }
            try? await sleep(ChefLoadingConfig.stage2ActivationMs)
        } else {
            let half = ChefLoadingConfig.stage2ActivationMs / 2
            Haptics.selection()
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35)) {
                leafScale = 1.0
            }
            withAnimation(.easeOut(duration: Double(half) / 1000)) {
                leafGlow = ChefLoadingConfig.leafActivationGlow
            }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 260, damping: 14)) {
                leafRotation = ChefLoadingConfig.leafActivationRotationDegrees
            }
            try? await sleep(half)
            // Volta ao repouso — "pulsa uma vez", não fica brilhando pro
            // resto da splash.
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 260, damping: 16)) {
                leafRotation = 0
            }
            withAnimation(.easeIn(duration: Double(half) / 1000)) {
                leafGlow = 0
            }
            try? await sleep(half)
        }

        // 3 · transição — partículas (círculos e mini-folhas) se expandem a
        // partir do ícone sem deslocá-lo do centro.
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) { particlesVisible = true }
        }
        try? await sleep(ChefLoadingConfig.stage3TransitionMs)

        // 4 · progresso (indeterminado) — condicional: só aparece se o
        // carregamento ainda não tiver terminado (RN.05/06). Hoje os dados
        // do Chef são locais e já estão prontos nesse ponto, então isso não
        // dispara na prática — decisão deliberada de não fingir um loading
        // que não existe, só pra bater com a duração "ideal" da splash.
        let dataAlreadyReady = true
        if !dataAlreadyReady {
            withAnimation(.easeIn(duration: 0.2)) {
                showRing = true
                ringTrim = reduceMotion ? 1.0 : 0.5
            }
            if !reduceMotion {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
            try? await sleep(ChefLoadingConfig.stage4ProgressMs)
        }

        // 5 · conclusão — o ícone volta com escala e spring, e o selo de
        // check surge.
        particlesVisible = false
        if showRing {
            withAnimation(.easeOut(duration: 0.2)) { showRing = false }
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { showCheck = true; checkScale = 1.0 }
        } else {
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 300, damping: 22)) {
                showCheck = true
                checkScale = 1.0
            }
        }
        Haptics.success()
        try? await sleep(ChefLoadingConfig.stage5CompletionMs)

        // 6 · feedback — traços curtos partindo do canto superior direito da
        // marca (não o mesmo canto do badge de check), expandindo e
        // desaparecendo.
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { showFeedbackStrokes = true }
        }
        try? await sleep(ChefLoadingConfig.stage6FeedbackMs)

        // Saída: fade sobreposto ao estado 6, sem tela preta intermediária.
        withAnimation(.easeInOut(duration: 0.25)) {
            markOpacity = 0
        }
        try? await sleep(ChefLoadingConfig.exitFadeMs)
        onFinished()
    }

    private func sleep(_ ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }
}

/// Mistura círculos e mini-folhas alternados por índice, cada um com uma
/// leve rotação própria enquanto voa — círculo sozinho ficava monótono
/// pro número de partículas que o estágio 3 pede.
private struct ChefLoadingParticle: View {
    let index: Int
    let total: Int
    @State private var animate = false

    private var angle: Double { Double(index) / Double(total) * 360 }
    private var isLeaf: Bool { index.isMultiple(of: 2) }
    private var spinDegrees: Double { isLeaf ? 50 : 20 }

    var body: some View {
        Group {
            if isLeaf {
                MiniLeafShape()
                    .fill(Color.chefPrimary)
                    .frame(width: 9, height: 11)
            } else {
                Circle()
                    .fill(Color.chefPrimary)
                    .frame(width: 6, height: 6)
            }
        }
        .rotationEffect(.degrees(animate ? spinDegrees : 0))
        .offset(
            x: animate ? CGFloat(cos(angle * .pi / 180)) * ChefLoadingConfig.particleTravelDistance : 0,
            y: animate ? CGFloat(sin(angle * .pi / 180)) * ChefLoadingConfig.particleTravelDistance : 0
        )
        .opacity(animate ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.03)) {
                animate = true
            }
        }
    }
}

/// Silhueta simples de folha pras mini-partículas do estágio 3 — não é a
/// mesma `ChefLeafShape` da marca (essa é ancorada e escalada pro ícone
/// inteiro); aqui é só um contorno de gota independente, pequeno o
/// bastante pra ler como "folha" a distância.
private struct MiniLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY))
        return path
    }
}

/// Estado 6 — traços curtos partindo do canto superior direito da marca
/// (não o mesmo canto do badge de check, que fica embaixo), expandindo e
/// desaparecendo.
private struct ChefFeedbackStrokes: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<ChefLoadingConfig.sparkCount, id: \.self) { index in
                let spread = Double(ChefLoadingConfig.sparkCount - 1) * 11
                let angle = Double(index) * 22 - spread
                Capsule()
                    .fill(Color.chefPrimary)
                    .frame(width: 3, height: 14)
                    .offset(y: animate ? -34 : -14)
                    .opacity(animate ? 0 : 1)
                    .rotationEffect(.degrees(angle))
            }
        }
        .offset(x: ChefLoadingConfig.sparkOffset.x, y: ChefLoadingConfig.sparkOffset.y)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { animate = true }
        }
    }
}

#Preview {
    ChefLoadingView(onFinished: {})
}
