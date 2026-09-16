import SwiftUI

enum ChefTab: String, Hashable {
    case hoje, dieta, scan, historico, perfil
}

/// Casca de navegação principal — Hoje · Dieta · Scan · Histórico · Perfil
/// (seção 8 do plano de migração). Usa o `TabView` nativo do iOS 26 com a
/// API `Tab(_:systemImage:content:)`: o sistema já aplica o material
/// Liquid Glass na barra automaticamente — não recriamos isso manualmente
/// como no PWA. O destaque do Scanner como "protagonista" é um refinamento
/// da Fase 2 (seção 9), depois que esta casca básica estiver validada.
///
/// A seleção é controlável via deep link (`chef://<aba>`) — usado pelo CI
/// pra navegar até uma aba específica e tirar screenshot dela sem precisar
/// de um teste de UI completo, já que não há Xcode local pra rodar um.
struct RootTabView: View {
    @State private var selection: ChefTab = .hoje

    var body: some View {
        TabView(selection: $selection) {
            Tab("Hoje", systemImage: "house.fill", value: ChefTab.hoje) {
                DashboardView()
            }
            Tab("Dieta", systemImage: "target", value: ChefTab.dieta) {
                DietView()
            }
            Tab("Scan", systemImage: "camera.fill", value: ChefTab.scan) {
                ScannerView()
            }
            Tab("Histórico", systemImage: "chart.line.uptrend.xyaxis", value: ChefTab.historico) {
                HistoryView()
            }
            Tab("Perfil", systemImage: "person.crop.circle", value: ChefTab.perfil) {
                ProfileView()
            }
        }
        .tint(.chefPrimary)
        .onOpenURL { url in
            if let tab = ChefTab(rawValue: url.host ?? "") {
                selection = tab
            }
        }
    }
}

#Preview {
    RootTabView()
}
