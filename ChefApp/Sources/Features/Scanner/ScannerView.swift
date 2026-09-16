import SwiftUI
import ChefCore

/// Tela de câmera fullscreen (seção 13): preview ao vivo com moldura de
/// vidro, captura → Vision → parser → confirmação. Nunca esconde do
/// usuário quando a câmera não está disponível (simulador/CI não têm
/// câmera física) — mostra um estado claro em vez de uma tela preta muda.
struct ScannerView: View {
    @StateObject private var camera = CameraModel()
    @State private var isProcessing = false
    @State private var scanResult: ScanResult?
    @State private var showResultSheet = false
    @State private var processingError: String?

    private let ocrProvider: OCRProvider = VisionTextRecognizer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.permission == .authorized && camera.isSessionRunning {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                statusOverlay
                Spacer()
                captureButton
                    .padding(.bottom, 32)
            }
        }
        .task {
            await camera.requestPermissionAndStart()
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showResultSheet) {
            if let scanResult {
                ScanResultSheet(scanResult: scanResult)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch camera.permission {
        case .notDetermined:
            ProgressView().tint(.white)
        case .denied:
            GlassMessage(
                icon: "camera.fill.badge.ellipsis",
                title: "Sem acesso à câmera",
                message: "Ative a permissão de câmera do Chef em Ajustes para escanear tabelas nutricionais."
            )
        case .authorized:
            if let error = camera.captureError, !camera.isSessionRunning {
                GlassMessage(icon: "camera.metering.unknown", title: "Câmera indisponível", message: error)
            } else if isProcessing {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Lendo tabela nutricional…")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.medium))
                }
            } else if let processingError {
                GlassMessage(icon: "exclamationmark.triangle", title: "Não deu pra ler", message: processingError)
            } else {
                Text("Centralize a tabela nutricional")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)
            }
        }
    }

    @ViewBuilder
    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            Circle()
                .fill(Color.chefPrimary)
                .frame(width: 80, height: 80)
                .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 4))
                .overlay(Image(systemName: "camera.fill").font(.title2).foregroundStyle(.white))
        }
        .disabled(!camera.isSessionRunning || isProcessing)
        .opacity(camera.isSessionRunning ? 1 : 0.4)
    }

    private func capture() async {
        isProcessing = true
        processingError = nil
        defer { isProcessing = false }

        guard let image = await camera.capturePhoto() else {
            processingError = "Não foi possível capturar a foto. Tente novamente."
            return
        }

        do {
            let lines = try await ocrProvider.extractLines(from: image)
            scanResult = NutritionLabelParser.parse(lines: lines)
            showResultSheet = true
        } catch {
            processingError = "Não foi possível analisar a imagem. Tente novamente."
        }
    }
}

private struct GlassMessage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 320)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview {
    ScannerView()
}
