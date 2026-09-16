import SwiftUI

/// Placeholder da Fase 1. Perfil, peso e disclaimers entram na Fase 7/8.
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Perfil",
                systemImage: "person.crop.circle",
                description: Text("Nome, peso e preferências chegam em breve.")
            )
            .navigationTitle("Perfil")
        }
    }
}

#Preview {
    ProfileView()
}
