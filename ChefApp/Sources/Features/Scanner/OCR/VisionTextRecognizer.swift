import Vision
import UIKit
import ChefCore

/// Abstração de OCR (seção 14 do plano de migração) — a UI depende só
/// deste protocolo, nunca do Vision diretamente, então trocar de provider
/// no futuro (ex: um serviço de IA mais robusto) não exige tocar nas telas.
protocol OCRProvider: Sendable {
    func extractLines(from image: UIImage) async throws -> [OCRLine]
}

/// Implementação real usando o Vision framework — reconhecimento de texto
/// nativo, sem enviar a imagem pra nenhum servidor.
struct VisionTextRecognizer: OCRProvider, Sendable {
    enum RecognitionError: Error {
        case invalidImage
    }

    func extractLines(from image: UIImage) async throws -> [OCRLine] {
        guard let cgImage = image.cgImage else { throw RecognitionError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [OCRLine] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRLine(text: candidate.string, confidence: Double(candidate.confidence))
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pt-BR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
