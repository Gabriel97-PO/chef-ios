import SwiftUI

/// Cor de marca do Chef — mesma referência usada no PWA (#FF7A00), não o
/// `.orange` do sistema (tom ligeiramente diferente). Ponto único de troca
/// caso a marca mude no futuro.
extension Color {
    static let chefPrimary = Color(red: 1.0, green: 0.478, blue: 0.0) // #FF7A00
    static let chefSuccess = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
}
