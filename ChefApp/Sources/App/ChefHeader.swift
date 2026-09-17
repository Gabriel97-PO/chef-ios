import SwiftUI

/// Header de marca usado no topo das telas principais — o app não tinha
/// identidade nenhuma além do título padrão de `NavigationStack`, só texto
/// preto em negrito. Substitui `.navigationTitle` visualmente (a barra de
/// navegação continua existindo, vazia, só pra manter a toolbar quando a
/// tela precisa de uma, como o "Importar" da Dieta).
struct ChefHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.chefPrimary.gradient)
                    .frame(width: 34, height: 34)
                Image(systemName: "fork.knife")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.chefOnPrimary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("CHEF")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
            }
            Spacer()
        }
    }
}
