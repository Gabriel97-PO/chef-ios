import SwiftUI

/// Parâmetros da splash "morphing container" centralizados aqui — tamanhos,
/// springs, durações de cada uma das 7 etapas, flag de partículas, e as
/// cores específicas dessa animação (fundo de tela e do container próprio,
/// diferentes das cores usadas no resto do app — só o laranja/Volt Green de
/// destaque é o mesmo `Color.chefPrimary` de sempre).
enum ChefLoadingConfig {
    // MARK: - Durações de cada etapa (ms), ≈2,6s no total

    static let stage1EntryMs: UInt64 = 350
    static let stage2ActivationMs: UInt64 = 250
    static let stage3MorphToCircleMs: UInt64 = 250
    static let stage4ProgressMs: UInt64 = 650
    static let stage5CompletionMs: UInt64 = 250
    static let stage6ReturnMs: UInt64 = 400
    static let stage7ExitMs: UInt64 = 450

    // MARK: - Container

    static let squareSide: CGFloat = 140
    /// ~22% do lado, estilo ícone de app.
    static let squareCornerRadius: CGFloat = squareSide * 0.22
    /// ~55% do tamanho original (estágio 3).
    static let circleDiameter: CGFloat = squareSide * 0.55
    static let circleCornerRadius: CGFloat = circleDiameter / 2
    /// Tamanho de sobra suficiente pra cobrir qualquer tela no estágio 7
    /// (a expansão final) sem precisar medir a tela via `GeometryReader`.
    static let fullscreenCoverSide: CGFloat = 1400
    /// O ícone (chapéu+faixa+folha) não preenche o container de ponta a
    /// ponta — sobra uma margem, como o glifo de um ícone de app de
    /// verdade dentro do quadrado.
    static let iconContentSize: CGFloat = squareSide * 0.72

    static let containerSpring = Animation.interpolatingSpring(mass: 1, stiffness: 300, damping: 30)

    // MARK: - Crossfade com blur (troca de conteúdo dentro do container)

    static let crossfadeOutMs: UInt64 = 120
    static let crossfadeInMs: UInt64 = 180
    /// A entrada começa antes da saída terminar — não é uma corrida
    /// sequencial, os dois se sobrepõem no meio.
    static let crossfadeOverlapMs: UInt64 = 40
    static let crossfadeBlur: CGFloat = 6
    static let crossfadeScale: CGFloat = 0.95

    // MARK: - Motion blur do container (durante mudanças grandes de tamanho)

    static let motionBlurAmount: CGFloat = 3

    // MARK: - Estágio 2 · ativação

    static let leafActivationRotationDegrees: Double = -8

    // MARK: - Estágio 2 · partículas (opcional, desligada por padrão)

    /// "OPCIONAL (flag desativada por padrão)" — deixa pronta pra ligar
    /// depois sem precisar reescrever nada, mas não roda hoje.
    static let particlesEnabled = false
    static let particleCount = 6
    static let particleTravelDistance: CGFloat = 70

    // MARK: - Estágio 4 · anel de progresso

    static let ringLineWidth: CGFloat = 5
    /// Trilha discreta atrás do arco de progresso — 10% de opacidade do
    /// contorno do container, não da cor de destaque.
    static let ringTrackOpacity: Double = 0.1
    /// Espaço entre a borda do container circular e o anel — o anel (e o
    /// check que ocupa o mesmo espaço) não encosta na borda do círculo.
    static let ringInset: CGFloat = 12

    // MARK: - Estágio 6 · badge de check

    static let checkBadgeDiameter: CGFloat = 40
    /// Canto inferior direito da folha — mesma posição já calibrada
    /// visualmente na splash anterior, geometria do ícone não mudou.
    static let checkBadgeOffset = CGPoint(x: 52, y: 54)

    // MARK: - Cores específicas dessa splash

    /// Fundo da tela por trás do container — diferente do
    /// `.systemBackground` do resto do app, valor exato pedido pro fluxo
    /// de marca desse estilo.
    static let screenBackground = dynamicColor(
        light: (0.929, 0.922, 0.906),  // #EDEBE7
        dark: (0.055, 0.055, 0.055)    // #0E0E0E
    )

    /// O container em si, quando mostra o ícone (não a cor de destaque).
    static let containerBackground = dynamicColor(
        light: (1.0, 1.0, 1.0),        // branco
        dark: (0.082, 0.082, 0.082)    // #151515
    )

    static let containerOutline = dynamicColor(
        light: (0.82, 0.82, 0.82),     // cinza
        dark: (0.24, 0.24, 0.24)       // grafite
    )

    private static func dynamicColor(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}
