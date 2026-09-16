import UIKit

/// Feedback tátil consistente nas ações-chave do Chef (polimento da Fase 2,
/// seção 9). `UIFeedbackGenerator` só é seguro no main thread, daí o
/// `@MainActor`.
@MainActor
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
