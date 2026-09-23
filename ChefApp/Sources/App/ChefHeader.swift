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
            // O ícone real do app (marca "BrandMark", cópia pequena do
            // AppIcon) no lugar do talher genérico — troca sozinho entre a
            // versão clara e escura via appearance do asset, igual o
            // ícone na tela inicial.
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9))
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
