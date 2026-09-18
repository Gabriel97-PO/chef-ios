import SwiftUI

/// Casca entre o lançamento e o app de verdade: o `RootTabView` já existe
/// por baixo (dados carregando em paralelo) enquanto a `ChefLoadingView`
/// cobre a tela com a animação de abertura, some sozinha ao terminar.
struct AppRootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootTabView()
            if showSplash {
                ChefLoadingView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
