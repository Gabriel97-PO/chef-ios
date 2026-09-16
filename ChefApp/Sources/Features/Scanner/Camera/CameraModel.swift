import AVFoundation
import UIKit

/// Encapsula a sessão de câmera (AVFoundation) e a captura de foto —
/// seção 13 do plano de migração. Nunca um componente web de câmera.
///
/// Importante para CI/simulador: o Simulador do iOS (e os runners do
/// GitHub Actions, que não têm câmera nenhuma) não conseguem iniciar uma
/// sessão de captura real. `isSessionRunning` reflete isso explicitamente
/// para a UI mostrar um estado claro em vez de uma tela preta silenciosa —
/// nunca esconder essa limitação do usuário.
@MainActor
final class CameraModel: NSObject, ObservableObject {
    enum PermissionState {
        case notDetermined, authorized, denied
    }

    @Published private(set) var permission: PermissionState = .notDetermined
    @Published private(set) var isSessionRunning = false
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var captureError: String?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureContinuation: CheckedContinuation<UIImage?, Never>?

    func requestPermissionAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
            await configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .denied
            if granted { await configureAndStart() }
        default:
            permission = .denied
        }
    }

    private func configureAndStart() async {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            captureError = "Não foi possível acessar a câmera traseira deste dispositivo."
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        session.startRunning()
        isSessionRunning = session.isRunning
        if !isSessionRunning {
            captureError = "A câmera não iniciou (comum em simuladores/CI, que não têm câmera física)."
        }
    }

    func stop() {
        session.stopRunning()
        isSessionRunning = false
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            photoCaptureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            self.capturedImage = image
            self.photoCaptureContinuation?.resume(returning: image)
            self.photoCaptureContinuation = nil
        }
    }
}
