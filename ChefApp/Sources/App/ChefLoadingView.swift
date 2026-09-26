import SwiftUI

/// Splash "morphing container" (fluxo de marca, estilo 2): um único
/// container que muda de forma/tamanho/cor entre 7 etapas — quadrado com o
/// ícone → ativação → círculo → anel de progresso → preenchido na cor de
/// destaque com check → volta ao quadrado com ícone → expande cobrindo a
/// tela. Chama `onFinished` ao final pra revelar o app.
///
/// Substituiu o estilo anterior (partículas saindo do ícone, ver histórico
/// de commits) por pedido explícito — o usuário não gostou daquele e trouxe
/// esse novo spec pra seguir à risca.
///
/// - `forceReduceMotion` e `speedMultiplier` só existem pra
///   `ChefLoadingPreviewView` conseguir simular "reduzir movimento" e tocar
///   em câmera lenta sem precisar mudar o ajuste do sistema.
struct ChefLoadingView: View {
    var onFinished: () -> Void
    var forceReduceMotion = false
    var speedMultiplier: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { forceReduceMotion || systemReduceMotion }

    /// Opacidade/blur/escala de uma camada de conteúdo dentro do container —
    /// ícone, anel e check trocam entre si assim, nunca via `.transition()`
    /// do SwiftUI (que não dá controle fino o bastante pra sair em 120ms e
    /// entrar em 180ms com sobreposição no meio).
    private struct LayerState {
        var opacity: Double = 0
        var blur: CGFloat = 0
        var scale: CGFloat = 1
    }

    @State private var containerSide: CGFloat = ChefLoadingConfig.squareSide
    @State private var containerCornerRadius: CGFloat = ChefLoadingConfig.squareCornerRadius
    @State private var containerFill: Color = ChefLoadingConfig.containerBackground
    @State private var containerOutlineOpacity: Double = 1
    @State private var containerBlur: CGFloat = 0
    @State private var containerPopScale: CGFloat = 0.9
    /// O container inteiro (não só o ícone) entra com fade — "container...
    /// aparece com opacity 0→1 e scale 0.9→1, com o ícone completo dentro".
    @State private var containerOpacity: Double = 0

    @State private var iconLayer = LayerState(opacity: 1)
    @State private var ringLayer = LayerState()
    @State private var checkLayer = LayerState()

    @State private var leafRotation: Double = 0
    @State private var stripeGlow: Double = 0
    @State private var ringTrim: CGFloat = 0
    @State private var checkTrim: CGFloat = 0

    @State private var showBadge = false
    @State private var badgeScale: CGFloat = 0

    @State private var overallOpacity: Double = 1

    var body: some View {
        ZStack {
            ChefLoadingConfig.screenBackground
                .ignoresSafeArea()

            ZStack {
                RoundedRectangle(cornerRadius: containerCornerRadius)
                    .fill(containerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: containerCornerRadius)
                            .stroke(ChefLoadingConfig.containerOutline.opacity(containerOutlineOpacity), lineWidth: 1.5)
                    )
                    .frame(width: containerSide, height: containerSide)

                iconContent
                    .opacity(iconLayer.opacity)
                    .blur(radius: iconLayer.blur)
                    .scaleEffect(iconLayer.scale)

                ringContent
                    .opacity(ringLayer.opacity)
                    .blur(radius: ringLayer.blur)
                    .scaleEffect(ringLayer.scale)

                checkContent
                    .opacity(checkLayer.opacity)
                    .blur(radius: checkLayer.blur)
                    .scaleEffect(checkLayer.scale)

                if showBadge {
                    badgeContent
                        .scaleEffect(badgeScale)
                }
            }
            .blur(radius: containerBlur)
            .scaleEffect(containerPopScale)
            .opacity(containerOpacity)
        }
        .opacity(overallOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(overallOpacity < 1 ? "Pronto" : "Carregando")
        .task { await runSequence() }
    }

    // MARK: - Conteúdo das camadas

    private var iconContent: some View {
        ZStack {
            ZStack {
                ChefHatShape().scale(1.055).fill(Color.chefPrimary)
                ChefHatShape().fill(Color.chefFigure)
            }

            ZStack {
                ChefStripeShape()
                    .fill(Color.chefPrimary)
                    .shadow(color: Color.chefPrimary.opacity(stripeGlow), radius: 10)
                ChefLeafShape()
                    .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            .rotationEffect(.degrees(leafRotation), anchor: UnitPoint(x: 0.70, y: 0.91))
        }
        .frame(width: ChefLoadingConfig.iconContentSize, height: ChefLoadingConfig.iconContentSize)
    }

    private var ringContent: some View {
        let diameter = ChefLoadingConfig.circleDiameter - ChefLoadingConfig.ringInset * 2
        return ZStack {
            Circle()
                .stroke(ChefLoadingConfig.containerOutline.opacity(ChefLoadingConfig.ringTrackOpacity), lineWidth: ChefLoadingConfig.ringLineWidth)
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: ChefLoadingConfig.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }

    private var checkContent: some View {
        let diameter = ChefLoadingConfig.circleDiameter - ChefLoadingConfig.ringInset * 2
        return CheckmarkShape()
            .trim(from: 0, to: checkTrim)
            .stroke(ChefLoadingConfig.screenBackground, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            .frame(width: diameter, height: diameter)
    }

    private var badgeContent: some View {
        Circle()
            .fill(Color.chefPrimary)
            .frame(width: ChefLoadingConfig.checkBadgeDiameter, height: ChefLoadingConfig.checkBadgeDiameter)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.chefOnPrimary)
            )
            .offset(x: ChefLoadingConfig.checkBadgeOffset.x, y: ChefLoadingConfig.checkBadgeOffset.y)
    }

    // MARK: - Sequência

    private func runSequence() async {
        if reduceMotion {
            await runReducedMotionSequence()
            return
        }

        // 1 · entrada — o container inteiro (não só o ícone) aparece com
        // fade + scale 0.9→1; o ícone já está visível dentro dele, sem
        // crossfade próprio nessa primeira entrada.
        withAnimation(anim(.easeOut(duration: 0.3))) {
            containerPopScale = 1.0
            containerOpacity = 1.0
        }
        await sleep(ChefLoadingConfig.stage1EntryMs)

        // 2 · ativação — a folha faz um ciclo de rotação (0°→-8°→0°) e a
        // faixa da base brilha uma vez. Partículas radiais são opcionais
        // (ChefLoadingConfig.particlesEnabled, desligada por padrão) e
        // entrariam aqui quando ligadas — não implementadas ainda.
        let half = ChefLoadingConfig.stage2ActivationMs / 2
        withAnimation(anim(.interpolatingSpring(mass: 1, stiffness: 260, damping: 14))) {
            leafRotation = ChefLoadingConfig.leafActivationRotationDegrees
        }
        withAnimation(anim(.easeOut(duration: Double(half) / 1000))) {
            stripeGlow = 0.8
        }
        await sleep(half)
        withAnimation(anim(.interpolatingSpring(mass: 1, stiffness: 260, damping: 16))) {
            leafRotation = 0
        }
        withAnimation(anim(.easeIn(duration: Double(half) / 1000))) {
            stripeGlow = 0
        }
        await sleep(half)

        // 3 · morph pra círculo — o ícone sai com crossfade+blur enquanto o
        // container encolhe e vira círculo, com motion blur leve durante a
        // mudança de tamanho. Nada entra no lugar do ícone ainda (o anel só
        // aparece na próxima etapa) — não é uma troca pareada, são duas
        // saídas/entradas soltas em sequência.
        exit($iconLayer)
        withAnimation(anim(ChefLoadingConfig.containerSpring)) {
            containerSide = ChefLoadingConfig.circleDiameter
            containerCornerRadius = ChefLoadingConfig.circleCornerRadius
            containerOutlineOpacity = 0
        }
        pulseMotionBlur()
        await sleep(ChefLoadingConfig.stage3MorphToCircleMs)

        // 4 · progresso — anel com trilha discreta desenha de 0° a 360°,
        // ease-in-out.
        enter($ringLayer)
        withAnimation(anim(.easeInOut(duration: Double(ChefLoadingConfig.stage4ProgressMs) / 1000))) {
            ringTrim = 1.0
        }
        await sleep(ChefLoadingConfig.stage4ProgressMs)

        // 5 · conclusão — o anel sai e o check entra (troca pareada, com
        // sobreposição no meio); o fundo do círculo vira a cor de destaque
        // em crossfade rápido com blur; o check desenha o traço.
        swap(out: $ringLayer, in: $checkLayer)
        withAnimation(anim(.easeInOut(duration: Double(ChefLoadingConfig.stage5CompletionMs) / 1000))) {
            containerFill = Color.chefPrimary
        }
        pulseMotionBlur()
        withAnimation(anim(.easeOut(duration: Double(ChefLoadingConfig.stage5CompletionMs) / 1000))) {
            checkTrim = 1.0
        }
        Haptics.success()
        await sleep(ChefLoadingConfig.stage5CompletionMs)

        // 6 · retorno — o check sai e o ícone volta a entrar (outra troca
        // pareada); o container volta a ser o quadrado; um badge de check
        // faz pop no canto da folha na segunda metade da etapa.
        swap(out: $checkLayer, in: $iconLayer)
        withAnimation(anim(ChefLoadingConfig.containerSpring)) {
            containerSide = ChefLoadingConfig.squareSide
            containerCornerRadius = ChefLoadingConfig.squareCornerRadius
            containerOutlineOpacity = 1
            containerFill = ChefLoadingConfig.containerBackground
        }
        pulseMotionBlur()
        await sleep(ChefLoadingConfig.stage6ReturnMs / 2)
        showBadge = true
        withAnimation(anim(.interpolatingSpring(mass: 1, stiffness: 400, damping: 14))) {
            badgeScale = 1.15
        }
        await sleep(120)
        withAnimation(anim(.easeOut(duration: 0.15))) {
            badgeScale = 1.0
        }
        await sleep(ChefLoadingConfig.stage6ReturnMs / 2 - 120)

        // 7 · saída — o container expande cobrindo a tela (motion blur
        // leve) na primeira metade da etapa; o ícone some com blur junto;
        // na segunda metade, a home aparece por baixo com fade. Tudo dentro
        // da janela de stage7ExitMs, pra bater com os ~2,6s totais do spec
        // em vez de somar mais tempo depois.
        let exitHalf = ChefLoadingConfig.stage7ExitMs / 2
        withAnimation(anim(ChefLoadingConfig.containerSpring)) {
            containerSide = ChefLoadingConfig.fullscreenCoverSide
            containerCornerRadius = 0
        }
        exit($iconLayer)
        pulseMotionBlur()
        await sleep(exitHalf)

        withAnimation(anim(.easeInOut(duration: Double(exitHalf) / 1000))) {
            overallOpacity = 0
        }
        await sleep(exitHalf)
        onFinished()
    }

    /// "Reduzir movimento" (AC pedida no spec): sem morph, sem blur, sem
    /// anel — só o ícone aparecendo com fade e a splash inteira some com
    /// fade pra revelar a home.
    private func runReducedMotionSequence() async {
        // "Apenas fade" — sem o pop de escala 0.9→1 mesmo, só opacidade.
        containerPopScale = 1.0
        withAnimation(anim(.easeOut(duration: 0.3))) {
            containerOpacity = 1.0
        }
        await sleep(1200)
        withAnimation(anim(.easeInOut(duration: 0.25))) {
            overallOpacity = 0
        }
        await sleep(250)
        onFinished()
    }

    // MARK: - Crossfade com blur
    //
    // Todas essas funções disparam a animação e voltam na hora — não
    // bloqueiam a sequência principal esperando a animação terminar. Quem
    // controla o ritmo de cada etapa é o `await sleep(stageXMs)` lá em
    // `runSequence`; aqui só orquestra a sobreposição *interna* entre saída
    // e entrada (quando as duas existem) via uma `Task` solta.

    /// Uma camada sozinha saindo, sem nada entrando no lugar dela ainda
    /// (estágios 3 e 7 — o ícone só some, o conteúdo seguinte aparece numa
    /// etapa posterior).
    private func exit(_ layer: Binding<LayerState>) {
        withAnimation(anim(.easeIn(duration: Double(ChefLoadingConfig.crossfadeOutMs) / 1000))) {
            layer.wrappedValue.opacity = 0
            layer.wrappedValue.blur = ChefLoadingConfig.crossfadeBlur
            layer.wrappedValue.scale = ChefLoadingConfig.crossfadeScale
        }
    }

    /// Uma camada sozinha entrando, sem nada tendo saído no mesmo instante
    /// (estágio 4 — o anel aparece num círculo já vazio).
    private func enter(_ layer: Binding<LayerState>) {
        layer.wrappedValue = LayerState(opacity: 0, blur: ChefLoadingConfig.crossfadeBlur, scale: ChefLoadingConfig.crossfadeScale)
        withAnimation(anim(.easeOut(duration: Double(ChefLoadingConfig.crossfadeInMs) / 1000))) {
            layer.wrappedValue.opacity = 1
            layer.wrappedValue.blur = 0
            layer.wrappedValue.scale = 1
        }
    }

    /// Uma camada saindo enquanto outra entra no lugar, com a entrada
    /// começando antes da saída terminar (estágios 5 e 6 — anel→check,
    /// check→ícone).
    private func swap(out: Binding<LayerState>, in inLayer: Binding<LayerState>) {
        exit(out)
        Task {
            await sleep(ChefLoadingConfig.crossfadeOutMs - ChefLoadingConfig.crossfadeOverlapMs)
            enter(inLayer)
        }
    }

    /// Blur leve (2-4px) que sobe e desce rápido, sincronizado com uma
    /// mudança grande de tamanho/cor do container — simula motion blur sem
    /// custar caro (só anima `blur(radius:)`, que já é leve no Metal).
    private func pulseMotionBlur() {
        withAnimation(anim(.easeOut(duration: 0.08))) {
            containerBlur = ChefLoadingConfig.motionBlurAmount
        }
        Task {
            await sleep(80)
            withAnimation(anim(.easeIn(duration: 0.12))) {
                containerBlur = 0
            }
        }
    }

    // MARK: - Utilidades de tempo/velocidade

    /// Aplica o multiplicador de velocidade da pré-visualização em qualquer
    /// animação — `Animation.speed` já cobre springs e curvas de tempo
    /// igual, então não precisa reescrever duração nenhuma na mão.
    private func anim(_ animation: Animation) -> Animation {
        speedMultiplier == 1 ? animation : animation.speed(speedMultiplier)
    }

    private func sleep(_ ms: UInt64) async {
        let scaledNs = UInt64(Double(ms) / speedMultiplier * 1_000_000)
        try? await Task.sleep(nanoseconds: scaledNs)
    }
}

/// Traço de check simples, desenhável com `.trim` — dois segmentos de reta
/// formando o "V" do check, pra animar o traço sendo desenhado em vez de um
/// glifo estático aparecendo de uma vez.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.74))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.26))
        return path
    }
}

#Preview {
    ChefLoadingView(onFinished: {})
}
