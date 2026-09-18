import SwiftUI
import ChefCore

/// Tela de câmera fullscreen (seção 13): preview ao vivo com moldura de
/// vidro, captura → Vision → parser → confirmação. Nunca esconde do
/// usuário quando a câmera não está disponível (simulador/CI não têm
/// câmera física) — mostra um estado claro em vez de uma tela preta muda.
///
/// A moldura de enquadramento centraliza a tabela nutricional na imagem e
/// padroniza o que é lido: a foto é recortada pra região da moldura antes
/// do OCR (`ScanFraming.imageRect`), em vez de mandar a foto inteira —
/// menos chance do parser se confundir com texto de fundo ou de outra
/// embalagem no enquadramento.
struct ScannerView: View {
    @StateObject private var camera = CameraModel()
    @State private var isProcessing = false
    @State private var scanResult: ScanResult?
    @State private var showResultSheet = false
    @State private var processingError: String?
    @State private var productName = ""
    @State private var viewSize: CGSize = .zero
    @FocusState private var nameFieldFocused: Bool

    private let ocrProvider: OCRProvider = VisionTextRecognizer()

    private var guideRect: CGRect { ScanFraming.defaultGuideRect(in: viewSize) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if camera.permission == .authorized && camera.isSessionRunning {
                    CameraPreviewView(session: camera.session)
                        .ignoresSafeArea()
                }

                if camera.permission == .authorized && camera.isSessionRunning && !isProcessing {
                    GuideFrameOverlay(rect: guideRect)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 16) {
                    productNameField
                    Spacer()
                    statusOverlay
                    Spacer()
                    captureButton
                        .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .onAppear { viewSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in viewSize = newSize }
        }
        .task {
            await camera.requestPermissionAndStart()
        }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $showResultSheet) {
            if let scanResult {
                ScanResultSheet(scanResult: scanResult, presetName: productName.trimmingCharacters(in: .whitespaces))
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: showResultSheet) { _, isShowing in
            if !isShowing { productName = "" }
        }
    }

    private var productNameField: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag")
                .foregroundStyle(.white.opacity(0.7))
            TextField("Nome do produto (opcional)", text: $productName)
                .foregroundStyle(.white)
                .focused($nameFieldFocused)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 20)
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
                Text("Centralize a tabela nutricional na moldura")
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
            Task { await captureFromButton() }
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

    // MARK: - Captura

    private func captureFromButton() async {
        nameFieldFocused = false
        Haptics.tap()
        isProcessing = true
        processingError = nil
        defer { isProcessing = false }

        guard let image = await camera.capturePhoto() else {
            Haptics.error()
            processingError = "Não foi possível capturar a foto. Tente novamente."
            return
        }

        let croppedImage = croppedToGuide(image)

        do {
            let lines = try await ocrProvider.extractLines(from: croppedImage ?? image)
            scanResult = NutritionLabelParser.parse(lines: lines)
            Haptics.success()
            showResultSheet = true
        } catch {
            Haptics.error()
            processingError = "Não foi possível analisar a imagem. Tente novamente."
        }
    }

    /// Recorta a foto pra região da moldura antes do OCR. Se o recorte
    /// falhar por qualquer motivo, devolve `nil` e quem chama usa a foto
    /// inteira — nunca trava o fluxo por causa da padronização.
    private func croppedToGuide(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage, viewSize != .zero else { return nil }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = ScanFraming.imageRect(forViewRect: guideRect, viewSize: viewSize, imageSize: imageSize)
        guard cropRect.width > 1, cropRect.height > 1, let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Moldura visual pra centralizar a tabela nutricional — fundo escurecido
/// fora da área útil, cantos em L na cor de marca, igual guia de scanner de
/// QR code/documento.
private struct GuideFrameOverlay: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            CornerBrackets()
                .stroke(Color.chefPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
        .ignoresSafeArea()
    }
}

private struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.09
        var path = Path()

        // topo-esquerda
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // topo-direita
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // baixo-direita
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        // baixo-esquerda
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
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
