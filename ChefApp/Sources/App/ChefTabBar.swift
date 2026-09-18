import SwiftUI

/// Barra de navegação customizada com Liquid Glass real (`.glassEffect`,
/// iOS 26) e o Scanner em destaque como "protagonista" (seção 9 da Fase 2):
/// um botão circular sólido na cor de marca, no centro da cápsula com os
/// outros quatro destinos. Substitui o `TabView` padrão do esqueleto
/// inicial (seção 8).
///
/// O botão do Scanner era vidro tintado (`.glassEffect(.tint)`) e ficava
/// pra fora da barra — a combinação de tint translúcido com sombra grande
/// borrava a borda do círculo e parecia um respingo de tinta. Agora é
/// preenchimento sólido, dentro da cápsula, como um item da barra.
///
/// A pílula de vidro atrás do item selecionado desliza entre as abas via
/// `matchedGeometryEffect` — o mesmo efeito que o `Picker` nativo em
/// `.segmented` já faz sozinho (visível no seletor de aba da tela Dieta),
/// só que aqui recriado à mão porque a barra é uma `HStack` customizada,
/// não um `Picker`. O Scanner fica de fora dessa pílula — ele já tem
/// destaque próprio (círculo sólido) e teria proporção estranha dividindo
/// espaço com um item quadrado como os outros.
struct ChefTabBar: View {
    @Binding var selection: ChefTab
    @Namespace private var highlightNamespace

    private let leadingItems: [ChefTabBarItem] = [
        .init(tab: .hoje, label: "Hoje", systemImage: "house.fill"),
        .init(tab: .dieta, label: "Dieta", systemImage: "target"),
    ]
    private let trailingItems: [ChefTabBarItem] = [
        .init(tab: .historico, label: "Histórico", systemImage: "chart.line.uptrend.xyaxis"),
        .init(tab: .perfil, label: "Perfil", systemImage: "person.crop.circle"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(leadingItems) { tabButton($0) }
            scanButton
                .frame(maxWidth: .infinity)
            ForEach(trailingItems) { tabButton($0) }
        }
        .padding(.horizontal, 10)
        .frame(height: 64)
        .glassEffect(in: .capsule)
    }

    private func tabButton(_ item: ChefTabBarItem) -> some View {
        let isSelected = selection == item.tab
        return Button {
            guard !isSelected else { return }
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = item.tab
            }
        } label: {
            VStack(spacing: 3) {
                icon(for: item, isSelected: isSelected)
                Text(item.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.chefPrimary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .glassEffect(.regular.tint(Color.chefPrimary.opacity(0.16)), in: .capsule)
                        .matchedGeometryEffect(id: "chef-tab-highlight", in: highlightNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Cada aba tem sua própria animação de SF Symbol ao ser selecionada —
    /// não é só trocar de cor, o ícone reage de um jeito que combina com o
    /// que ele representa.
    @ViewBuilder
    private func icon(for item: ChefTabBarItem, isSelected: Bool) -> some View {
        let base = Image(systemName: item.systemImage)
            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.chefPrimary : Color.secondary)

        switch item.tab {
        case .hoje:
            base.symbolEffect(.bounce, value: isSelected)
        case .dieta:
            base.symbolEffect(.pulse, value: isSelected)
        case .historico:
            base.symbolEffect(.wiggle, value: isSelected)
        case .perfil:
            base.symbolEffect(.breathe, value: isSelected)
        default:
            base
        }
    }

    private var scanButton: some View {
        let isSelected = selection == .scan
        return Button {
            guard !isSelected else { return }
            Haptics.tap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = .scan
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.chefPrimary)
                Image(systemName: "camera.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.chefOnPrimary)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.chefPrimary.opacity(0.35), radius: 6, y: 2)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .accessibilityLabel("Scan")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ChefTabBarItem: Identifiable {
    let tab: ChefTab
    let label: String
    let systemImage: String
    var id: ChefTab { tab }
}

#Preview {
    @Previewable @State var selection: ChefTab = .hoje
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.1).ignoresSafeArea()
        ChefTabBar(selection: $selection)
            .padding(.horizontal, 20)
    }
}
