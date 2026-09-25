import Foundation
import CoreGraphics

/// Parâmetros da splash centralizados aqui pra ajuste rápido sem precisar
/// mexer na lógica de `ChefLoadingView` — durações, contagens e distâncias,
/// não cores (essas continuam em `Color.chefPrimary`/`chefSuccess`, ponto
/// único de marca que a splash só referencia).
enum ChefLoadingConfig {
    // MARK: - Durações de cada estágio (ms)

    static let stage1IntroMs: UInt64 = 300
    static let stage2ActivationMs: UInt64 = 400
    static let stage3TransitionMs: UInt64 = 400
    static let stage4ProgressMs: UInt64 = 700
    static let stage5CompletionMs: UInt64 = 400
    static let stage6FeedbackMs: UInt64 = 400
    static let exitFadeMs: UInt64 = 250

    // MARK: - Estágio 1 · início

    static let introStartScale: CGFloat = 0.92

    // MARK: - Estágio 2 · ativação

    /// Um ciclo só (-8°→0°, spring), não balanço contínuo — a folha "acorda"
    /// e assenta, em vez de ficar balançando pra sempre durante toda a
    /// splash.
    static let leafActivationRotationDegrees: Double = -8
    static let leafActivationGlow: Double = 0.7

    // MARK: - Estágio 3 · transição (partículas)

    /// Mistura de círculos e mini-folhas, intercalados por índice.
    static let particleCount = 7
    static let particleTravelDistance: CGFloat = 96

    // MARK: - Estágio 4 · progresso (anel)

    static let ringDiameter: CGFloat = 184
    static let ringLineWidth: CGFloat = 6

    // MARK: - Estágio 5 · conclusão (badge de check)

    static let checkBadgeDiameter: CGFloat = 44
    static let checkBadgeOffset = CGPoint(x: 52, y: 54)

    // MARK: - Estágio 6 · feedback (sparks)

    /// Canto superior direito da marca — não o mesmo canto do badge de
    /// check (inferior direito), pra não competir visualmente com ele.
    static let sparkCount = 4
    static let sparkOffset = CGPoint(x: 52, y: -54)

    // MARK: - Marca

    static let markSize: CGFloat = 140
}
