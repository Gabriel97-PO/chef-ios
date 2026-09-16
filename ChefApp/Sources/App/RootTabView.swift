import SwiftUI

/// Casca de navegação principal — Hoje · Dieta · Scan · Histórico · Perfil
/// (seção 8 do plano de migração). Usa o `TabView` nativo do iOS 26 com a
/// API `Tab(_:systemImage:content:)`: o sistema já aplica o material
/// Liquid Glass na barra automaticamente — não recriamos isso manualmente
/// como no PWA. O destaque do Scanner como "protagonista" é um refinamento
/// da Fase 2 (seção 9), depois que esta casca básica estiver validada.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Hoje", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("Dieta", systemImage: "target") {
                DietView()
            }
            Tab("Scan", systemImage: "camera.fill") {
                ScannerView()
            }
            Tab("Histórico", systemImage: "chart.line.uptrend.xyaxis") {
                HistoryView()
            }
            Tab("Perfil", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
    }
}

#Preview {
    RootTabView()
}
