import SwiftUI
import UIKit

/// Paleta do Chef. Ponto único de troca caso a marca mude.
///
/// O app tem duas identidades que trocam sozinhas com o tema do iPhone
/// (roadmap item 9): claro = laranja da marca (#FF7A00, o mesmo do PWA);
/// escuro = preto com Volt Green (#CCFF00), a cor definida no fluxo de
/// marca do ícone. Não é o `.orange`/`.green` do sistema.
///
/// Usa `UIColor(dynamicProvider:)` em vez de `@Environment(\.colorScheme)`
/// porque assim a cor se resolve sozinha em qualquer contexto — inclusive
/// dentro de `Chart`, `UIViewRepresentable` e material de vidro, onde não
/// há como ler o Environment do SwiftUI.
extension Color {
    /// Acento primário: calorias, seleção, botões de ação.
    static let chefPrimary = chefDynamic(
        light: (1.0, 0.478, 0.0),      // #FF7A00
        dark: (0.8, 1.0, 0.0)          // #CCFF00 — Volt Green
    )

    /// Acento secundário: proteína, confirmações.
    static let chefSuccess = chefDynamic(
        light: (0.133, 0.773, 0.369),  // #22C55E
        dark: (0.0, 0.898, 1.0)        // #00E5FF — no escuro o primário já é
                                       // verde, então o sucesso vira ciano
                                       // pra não virar tudo a mesma cor
    )

    /// Conteúdo sobre `chefPrimary` preenchido. Preto no escuro porque texto
    /// branco sobre verde neon tem contraste ruim.
    static let chefOnPrimary = chefDynamic(
        light: (1.0, 1.0, 1.0),
        dark: (0.0, 0.0, 0.0)
    )

    /// Token `figure` do fluxo de marca — corpo do chapéu na marca/ícone.
    /// Nunca `.primary`: `.primary` é texto do sistema (branco no escuro),
    /// e o chapéu tem que ficar quase-preto no escuro (mesmo tom do ícone,
    /// contorno sutil contra o fundo, nunca branco saltando aos olhos).
    static let chefFigure = chefDynamic(
        light: (1.0, 1.0, 1.0),        // #FFFFFF
        dark: (0.039, 0.039, 0.039)    // #0A0A0A
    )

    /// Contorno sutil do chapéu — sem ele, `chefFigure` (quase branco no
    /// claro, quase preto no escuro) some contra um fundo praticamente da
    /// mesma cor. Mesmos tons usados na geração do ícone do app.
    static let chefFigureOutline = chefDynamic(
        light: (0.863, 0.847, 0.820),  // cinza claro
        dark: (0.180, 0.180, 0.180)    // cinza escuro
    )

    private static func chefDynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}
