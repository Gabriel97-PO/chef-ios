import Foundation

/// Remove acentos e normaliza para minúsculas — usado em matching aproximado de nomes.
public func normalizeText(_ value: String) -> String {
    let folded = value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    return folded.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
}
