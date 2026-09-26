import SwiftUI

/// Parâmetros da splash "morphing container" centralizados aqui — valores
/// calibrados a partir de um protótipo de referência (config JS/HTML que o
/// usuário passou), não inventados: tamanhos, springs, curvas de tempo
/// exatas (cubic-bezier), durações de cada etapa (incluindo as pausas
/// "hold" depois da conclusão e do retorno), flag de partículas, e as cores
/// específicas dessa animação. Só o laranja/Volt Green de destaque é o
/// mesmo `Color.chefPrimary` de sempre — o resto da paleta aqui é próprio
/// dessa splash.
enum ChefLoadingConfig {
    // MARK: - Tamanhos

    static let squareSide: CGFloat = 160
    static let squareCornerRadius: CGFloat = 36
    static let circleDiameter: CGFloat = 88
    static let circleCornerRadius: CGFloat = circleDiameter / 2
    /// Raio que o container assume ao cobrir a tela inteira (estágio 7) —
    /// não é 0: imita o raio de canto do próprio aparelho, em vez de virar
    /// um retângulo reto de repente. Só faz sentido visualmente se o
    /// container crescer até perto do tamanho real da tela (ver
    /// `fullscreenOverscanFactor`) — um valor de sobra gigantesco deixaria
    /// esse raio imperceptível por comparação.
    static let screenCornerRadius: CGFloat = 40
    /// Multiplicador sobre a maior dimensão da tela (medida via
    /// `UIScreen.main.bounds` na hora, não fixo aqui) — sobra o bastante
    /// pra cobrir cantos e notch sem precisar de `GeometryReader`, mas sem
    /// exagerar a ponto do `screenCornerRadius` sumir na escala.
    static let fullscreenOverscanFactor: CGFloat = 1.15
    /// Não vem do protótipo de referência (que não expõe o glifo
    /// separado do container) — mantém a mesma proporção de margem interna
    /// já calibrada visualmente antes.
    static let iconContentSize: CGFloat = squareSide * 0.72

    // MARK: - Durações de cada etapa (ms)

    static let stage1EntryMs: UInt64 = 350
    static let stage2ActivationMs: UInt64 = 260
    static let stage3MorphToCircleMs: UInt64 = 260
    static let stage4ProgressMs: UInt64 = 650
    static let stage5CompletionMs: UInt64 = 220
    /// Pausa depois do check desenhado, antes de começar a voltar — dá
    /// tempo da conclusão "respirar" em vez de já sair encolhendo.
    static let stage5HoldMs: UInt64 = 280
    static let stage6ReturnMs: UInt64 = 380
    /// Pausa depois do ícone (e do badge) de volta, antes da saída final.
    static let stage6HoldMs: UInt64 = 300
    static let stage7ExitMs: UInt64 = 520

    // MARK: - Springs

    /// Redimensionamento do container (quadrado↔círculo↔quadrado).
    static let shapeSpring = Animation.interpolatingSpring(mass: 1, stiffness: 300, damping: 30)
    /// Pops de escala (badge de check).
    static let popSpring = Animation.interpolatingSpring(mass: 1, stiffness: 420, damping: 16)
    /// Expansão final cobrindo a tela — mais solta que `shapeSpring` de
    /// propósito, pra não parecer um "salto" numa mudança de tamanho tão
    /// grande.
    static let expandSpring = Animation.interpolatingSpring(mass: 1, stiffness: 200, damping: 26)

    // MARK: - Curvas de tempo (cubic-bezier exatas do protótipo)

    static func progressEasing(_ durationMs: UInt64) -> Animation {
        .timingCurve(0.65, 0, 0.35, 1, duration: Double(durationMs) / 1000)
    }

    static func fadeInEasing(_ durationMs: UInt64) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: Double(durationMs) / 1000)
    }

    static func fadeOutEasing(_ durationMs: UInt64) -> Animation {
        .timingCurve(0.4, 0, 1, 1, duration: Double(durationMs) / 1000)
    }

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

    static let leafActivationRotationDegrees: Double = -9

    // MARK: - Estágio 2 · partículas (opcional, desligada por padrão)

    static let particlesEnabled = false
    static let particleCount = 6
    static let particleTravelDistance: CGFloat = 34
    static let particleDurationMs: UInt64 = 520

    // MARK: - Estágio 4 · anel de progresso

    static let ringLineWidth: CGFloat = 5
    /// Trilha discreta atrás do arco de progresso — 10% de opacidade do
    /// contorno do container, não da cor de destaque.
    static let ringTrackOpacity: Double = 0.1
    /// Espaço entre a borda do container circular e o anel.
    static let ringInset: CGFloat = 12

    // MARK: - Estágio 6 · badge de check

    static let checkBadgeDiameter: CGFloat = 40
    /// Canto inferior direito da folha — escalado na mesma proporção do
    /// aumento do container (era calibrado pra um container de 140, este é
    /// 160: ×1,143).
    static let checkBadgeOffset = CGPoint(x: 59, y: 62)

    // MARK: - Cores específicas dessa splash

    /// Fundo da tela por trás do container.
    static let screenBackground = dynamicColor(
        light: (0xF2, 0xF2, 0xF0),
        dark: (0x0F, 0x0F, 0x0F)
    )

    /// O container em si, quando mostra o ícone (não a cor de destaque).
    static let containerBackground = dynamicColor(
        light: (0xFF, 0xFF, 0xFF),
        dark: (0x1A, 0x1A, 0x1A)
    )

    static let containerOutline = dynamicColor(
        light: (0xA0, 0x9B, 0x93),
        dark: (0x56, 0x56, 0x56)
    )

    /// Cor do check grande e do glifo do badge — contraste sobre a cor de
    /// destaque preenchida. Não é o mesmo `Color.chefOnPrimary` global do
    /// app (usado em botões o app inteiro): aqui os valores exatos do
    /// protótipo são levemente diferentes (branco puro no claro; no escuro,
    /// bate com o próprio fundo da tela, não com preto puro).
    static let onAccent = dynamicColor(
        light: (0xFF, 0xFF, 0xFF),
        dark: (0x0F, 0x0F, 0x0F)
    )

    private static func dynamicColor(light: (UInt8, UInt8, UInt8), dark: (UInt8, UInt8, UInt8)) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(rgb.0) / 255,
                green: CGFloat(rgb.1) / 255,
                blue: CGFloat(rgb.2) / 255,
                alpha: 1
            )
        })
    }
}
