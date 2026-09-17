import SwiftUI

enum ChefTab: String, Hashable {
    case hoje, dieta, scan, historico, perfil
}

/// Casca de navegação principal — Hoje · Dieta · Scan · Histórico · Perfil
/// (seção 8 do plano de migração). A validação inicial usou o `TabView`
/// nativo do iOS 26; agora que o produto está funcionando, trocamos pela
/// `ChefTabBar` customizada para dar ao Scanner o destaque de "protagonista"
/// previsto na seção 9 — um botão elevado, próprio, que o `Tab(...)` padrão
/// não permite diferenciar dos demais.
///
/// A seleção é controlável via deep link (`chef://<aba>`) — usado pelo CI
/// pra navegar até uma aba específica e tirar screenshot dela sem precisar
/// de um teste de UI completo, já que não há Xcode local pra rodar um.
struct RootTabView: View {
    @State private var selection: ChefTab = .hoje

    var body: some View {
        content
            .safeAreaInset(edge: .bottom) {
                ChefTabBar(selection: $selection)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            // Tinge os controles de sistema (botões, pickers, cursor) com a
            // cor da marca em vez do azul padrão do iOS.
            .tint(Color.chefPrimary)
            .onOpenURL { url in
                if let tab = ChefTab(rawValue: url.host ?? "") {
                    selection = tab
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .hoje: DashboardView()
        case .dieta: DietView()
        case .scan: ScannerView()
        case .historico: HistoryView()
        case .perfil: ProfileView()
        }
    }
}

#Preview {
    RootTabView()
}
