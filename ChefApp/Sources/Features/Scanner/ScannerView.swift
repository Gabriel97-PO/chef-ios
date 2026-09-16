import SwiftUI

/// Placeholder da Fase 1. AVFoundation + Vision + parser entram na Fase 5
/// do plano de migração (seção 42): Camera → Vision → OCR → Parser →
/// Validation → Confirmation → Portion → "Cabe na dieta?".
struct ScannerView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Cabe na dieta?",
                systemImage: "camera.viewfinder",
                description: Text("O scanner com câmera nativa e Vision chega na próxima fase.")
            )
            .navigationTitle("Scan")
        }
    }
}

#Preview {
    ScannerView()
}
