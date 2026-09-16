import Foundation

/// Confiança contínua (0-1) de um campo lido pelo OCR/IA — nunca binária.
/// Um campo ausente (não reconhecido) nunca é representado como confiança
/// zero; ele simplesmente não existe no `ScanResult` (é `nil`).
public struct ScanField<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var value: T
    /// 0.0 a 1.0.
    public var confidence: Double

    public init(value: T, confidence: Double) {
        self.value = value
        self.confidence = confidence
    }
}

public enum ConfidenceTier: String, Sendable {
    case high
    case review
    case unrecognized
}

/// Classifica a confiança de um campo em um dos três estados visuais
/// 🟢/🟡/🔴 do Chef. `nil` (campo nunca identificado) é sempre
/// `.unrecognized` — nunca vira "confiança zero" por acidente.
public func confidenceTier(_ confidence: Double?) -> ConfidenceTier {
    guard let confidence else { return .unrecognized }
    if confidence >= 0.85 { return .high }
    if confidence >= 0.5 { return .review }
    return .unrecognized
}
