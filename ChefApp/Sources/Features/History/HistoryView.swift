import SwiftUI

/// Placeholder da Fase 1. Consumo, peso e tendências entram na Fase 7.
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Histórico",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Evolução de consumo e peso chega na Fase 7.")
            )
            .navigationTitle("Histórico")
        }
    }
}

#Preview {
    HistoryView()
}
