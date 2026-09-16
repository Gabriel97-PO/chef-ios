import SwiftUI

/// Barra de navegação customizada com Liquid Glass real (`.glassEffect`,
/// iOS 26) e o Scanner em destaque como "protagonista" (seção 9 da Fase 2):
/// um botão circular elevado, tintado na cor de marca, flutuando acima da
/// cápsula com os outros quatro destinos. Substitui o `TabView` padrão do
/// esqueleto inicial (seção 8), que já validamos funcionando antes de vir
/// esse refinamento visual.
struct ChefTabBar: View {
    @Binding var selection: ChefTab
    @Namespace private var glassNamespace

    private let leadingItems: [ChefTabBarItem] = [
        .init(tab: .hoje, label: "Hoje", systemImage: "house.fill"),
        .init(tab: .dieta, label: "Dieta", systemImage: "target"),
    ]
    private let trailingItems: [ChefTabBarItem] = [
        .init(tab: .historico, label: "Histórico", systemImage: "chart.line.uptrend.xyaxis"),
        .init(tab: .perfil, label: "Perfil", systemImage: "person.crop.circle"),
    ]

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            ZStack {
                HStack(spacing: 0) {
                    ForEach(leadingItems) { tabButton($0) }
                    Spacer().frame(width: 68)
                    ForEach(trailingItems) { tabButton($0) }
                }
                .padding(.horizontal, 14)
                .frame(height: 64)
                .glassEffect(in: .capsule)
                .glassEffectID("bar", in: glassNamespace)

                scanButton
                    .glassEffectID("scan", in: glassNamespace)
                    .offset(y: -22)
            }
        }
    }

    private func tabButton(_ item: ChefTabBarItem) -> some View {
        let isSelected = selection == item.tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = item.tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                Text(item.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.chefPrimary : Color.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
    }

    private var scanButton: some View {
        let isSelected = selection == .scan
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selection = .scan
            }
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.chefPrimary).interactive(), in: .circle)
        .shadow(color: Color.chefPrimary.opacity(0.35), radius: isSelected ? 18 : 12, y: 6)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .accessibilityLabel("Scan")
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
