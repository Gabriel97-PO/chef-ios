import Foundation
import ChefCore

/// Um item encontrado na busca online — mesma ideia do `ReferenceFood`,
/// mas vindo de fora do app.
struct NetworkFoodResult: Identifiable {
    var id: String { name }
    let name: String
    let per100g: NutritionFacts
}

enum OpenFoodFactsError: LocalizedError {
    case network
    case noResults

    var errorDescription: String? {
        switch self {
        case .network: return "Não foi possível buscar agora. Confira sua internet e tente de novo."
        case .noResults: return "Nada encontrado com esse nome na base online."
        }
    }
}

/// Busca alimentos que não estão na base local nem na de referência
/// (roadmap: "deverá ser realizada uma pesquisa em algum lugar").
///
/// Usa o Open Food Facts (world.openfoodfacts.org) por ser a única base
/// de alimentos com cobertura relevante do Brasil que é de verdade grátis
/// e sem cadastro — não precisa de chave de API, então não depende de
/// nenhuma conta ou pagamento pra funcionar. A contrapartida: é uma base
/// colaborativa focada em produtos com código de barras (embalados), não
/// em pratos/ingredientes soltos — cobre bem itens industrializados, mas
/// pode não achar algo tipo "picanha na brasa" caseira. Continua sendo só
/// uma camada a mais: local → base de referência → online, nessa ordem.
enum OpenFoodFactsService {
    static func search(_ query: String) async throws -> [NetworkFoodResult] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "8"),
            URLQueryItem(name: "fields", value: "product_name,nutriments"),
        ]
        guard let url = components.url else { throw OpenFoodFactsError.network }

        var request = URLRequest(url: url)
        // O Open Food Facts pede um User-Agent identificável pra quem consome a API.
        request.setValue("Chef-iOS/1.0 (github.com/Gabriel97-PO/chef-ios)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenFoodFactsError.network
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenFoodFactsError.network
        }

        guard let decoded = try? JSONDecoder().decode(OFFSearchResponse.self, from: data) else {
            throw OpenFoodFactsError.network
        }

        let results = decoded.products.compactMap(\.asNetworkFoodResult)
        guard !results.isEmpty else { throw OpenFoodFactsError.noResults }
        return results
    }
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProduct: Decodable {
    let productName: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case nutriments
    }

    /// `nil` quando faltam os dados mínimos (nome ou calorias) — nunca
    /// inventa um valor pra um produto sem informação nutricional real.
    var asNetworkFoodResult: NetworkFoodResult? {
        guard let productName, !productName.trimmingCharacters(in: .whitespaces).isEmpty,
              let nutriments, let calories = nutriments.caloriesPer100g
        else { return nil }

        return NetworkFoodResult(
            name: productName,
            per100g: NutritionFacts(
                calories: calories,
                protein: nutriments.proteinsPer100g ?? 0,
                carbs: nutriments.carbohydratesPer100g ?? 0,
                fat: nutriments.fatPer100g ?? 0,
                fiber: nutriments.fiberPer100g,
                // Open Food Facts reporta sódio em gramas; o resto do app
                // usa miligramas (mesma unidade que aparece nas tabelas
                // nutricionais escaneadas).
                sodium: nutriments.sodiumPer100g.map { $0 * 1000 }
            )
        )
    }
}

private struct OFFNutriments: Decodable {
    let caloriesPer100g: Double?
    let proteinsPer100g: Double?
    let carbohydratesPer100g: Double?
    let fatPer100g: Double?
    let fiberPer100g: Double?
    let sodiumPer100g: Double?

    enum CodingKeys: String, CodingKey {
        case caloriesPer100g = "energy-kcal_100g"
        case proteinsPer100g = "proteins_100g"
        case carbohydratesPer100g = "carbohydrates_100g"
        case fatPer100g = "fat_100g"
        case fiberPer100g = "fiber_100g"
        case sodiumPer100g = "sodium_100g"
    }

    // O Open Food Facts serializa esses campos ora como número, ora como
    // string ("88.1") — inconsistente até entre produtos diferentes na
    // mesma resposta. `Decodable` sintetizado falha o JSON inteiro na
    // primeira inconsistência (é por isso que a busca online "não
    // acontecia": qualquer produto com um campo em formato de string
    // derrubava a decodificação da resposta toda, silenciosamente, e caía
    // no erro genérico de rede). Aceitar os dois formatos aqui é o que
    // resolve.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caloriesPer100g = try Self.flexibleDouble(container, .caloriesPer100g)
        proteinsPer100g = try Self.flexibleDouble(container, .proteinsPer100g)
        carbohydratesPer100g = try Self.flexibleDouble(container, .carbohydratesPer100g)
        fatPer100g = try Self.flexibleDouble(container, .fatPer100g)
        fiberPer100g = try Self.flexibleDouble(container, .fiberPer100g)
        sodiumPer100g = try Self.flexibleDouble(container, .sodiumPer100g)
    }

    private static func flexibleDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Double? {
        // `try?` sobre uma chamada que já devolve `Optional` não aninha
        // (achata desde a SE-0230) — por isso um único `if let` já basta
        // aqui, sem precisar de um segundo `let` pra desembrulhar de novo.
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key) {
            return raw.flatMap(Double.init)
        }
        return nil
    }
}
