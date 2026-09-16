import Foundation

/// Uma linha de texto reconhecida pelo OCR (Vision, no app), com a
/// confiança que o próprio reconhecedor atribuiu a ela. Diferente do mock
/// do PWA, essa confiança é real — vem do `VNRecognizedText.confidence` de
/// cada observação, não é sorteada.
public struct OCRLine: Sendable, Equatable {
    public var text: String
    /// 0.0 a 1.0, conforme reportado pelo Vision.
    public var confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
    }
}
