import SwiftUI

/// Cartão em Liquid Glass real, reutilizado por todas as telas do Chef em
/// vez de repetir `.padding(...)` + `.glassEffect(in: .rect(cornerRadius:))`
/// View a View (item de Design System da Fase 2, seção 9).
private struct ChefGlassCard: ViewModifier {
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func chefGlassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(ChefGlassCard(cornerRadius: cornerRadius, padding: padding))
    }
}
