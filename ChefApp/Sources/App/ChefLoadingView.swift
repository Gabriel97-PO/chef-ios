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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var leafScale: CGFloat = 0.92
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
                .frame(width: 140, height: 140)

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
                .frame(width: 140, height: 140)
                .shadow(color: Color.chefPrimary.opacity(leafGlow), radius: 20)
                .scaleEffect(leafScale)
                // Ancorado perto da base da folha (onde ela "nasce" do
                // chapéu), não no centro — assim o balanço lê como um
                // talo balançando, não a folha inteira girando no lugar.
                .rotationEffect(.degrees(leafRotation), anchor: UnitPoint(x: 0.70, y: 0.91))

                if showFeedbackStrokes {
                    ChefFeedbackStrokes()
                        .frame(width: 140, height: 140)
                }

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showCheck ? "Pronto" : "Carregando")
        .task { await runSequence() }
    }

    private func runSequence() async {
        // 1 · início (200ms, linear) — ícone estático em repouso.
        try? await sleep(200)

        // 2 · ativação (350ms, easeOut(.2,0,0,1)) — a folha ganha vida:
        // escala de 0.92 pra 1.0, brilho do acento, e entra num balanço
        // contínuo (o "movimento relacionado ao logo" que dá a sensação
        // de folha viva, em vez de um ícone estático com glow). O
        // restante do ícone (o chapéu) permanece parado o tempo todo.
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { leafScale = 1.0; leafGlow = 0.55 }
        } else {
            Haptics.selection()
            withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.35)) {
                leafScale = 1.0
                leafGlow = 0.7
            }
            leafRotation = -9
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                leafRotation = 9
            }
        }
        try? await sleep(350)

        // 3 · transição (300ms, easeInOut) — partículas se expandem a
        // partir do ícone sem deslocá-lo do centro.
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) { particlesVisible = true }
        }
        try? await sleep(300)

        // 4 · progresso (indeterminado) — condicional: só aparece se o
        // carregamento ainda não tiver terminado (RN.05/06). Hoje os
        // dados do Chef são locais e já estão prontos nesse ponto, então
        // isso não dispara na prática — ver nota na doc do tipo.
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
            try? await sleep(1200)
        }

        // 5 · conclusão (400ms, spring rigidez 300/amortecimento 22) — o
        // ícone volta com escala 0.9→1.0 e o selo de check surge.
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
        try? await sleep(400)

        // 6 · feedback (300ms, easeOut) — micro feedback: traços curtos
        // partindo da folha, expandindo e desaparecendo.
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { showFeedbackStrokes = true }
        }
        try? await sleep(300)

        // Saída: fade sobreposto ao estado 6, sem tela preta intermediária.
        withAnimation(.easeInOut(duration: 0.25)) {
            markOpacity = 0
        }
        try? await sleep(250)
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
                x: animate ? CGFloat(cos(angle * .pi / 180)) * 96 : 0,
                y: animate ? CGFloat(sin(angle * .pi / 180)) * 96 : 0
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.03)) {
                    animate = true
                }
            }
    }
}

/// Estado 6 — três traços curtos partindo da folha (canto inferior
/// direito da marca), expandindo e desaparecendo.
private struct ChefFeedbackStrokes: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let angle = Double(index) * 22 - 22
                Capsule()
                    .fill(Color.chefPrimary)
                    .frame(width: 3, height: 14)
                    .offset(y: animate ? -34 : -14)
                    .opacity(animate ? 0 : 1)
                    .rotationEffect(.degrees(angle))
            }
        }
        .offset(x: 52, y: 54)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { animate = true }
        }
    }
}

#Preview {
    ChefLoadingView(onFinished: {})
}
