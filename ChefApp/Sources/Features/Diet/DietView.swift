import SwiftUI

/// Placeholder da Fase 1 — casca de navegação. Metas, refeições fixas,
/// receitas e importação CNP entram na Fase 4 do plano de migração.
struct DietView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Minha dieta",
                systemImage: "target",
                description: Text("Metas, refeições fixas, receitas e importação CNP chegam na próxima fase.")
            )
            .navigationTitle("Dieta")
        }
    }
}

#Preview {
    DietView()
}
