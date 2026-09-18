import Foundation

/// Um alimento da base de referência — valores médios por 100g/100ml,
/// não um produto de marca específica.
public struct ReferenceFood: Identifiable, Sendable, Equatable {
    public var id: String { name }
    public var name: String
    public var unit: PortionUnit
    /// Nutrição por 100 (g ou ml, conforme `unit`).
    public var per100: NutritionFacts
    /// Peso médio de 1 unidade (ex: 1 bife, 1 ovo, 1 banana) — só quando
    /// contar por peça faz sentido de verdade. `nil` pra alimentos que só
    /// se medem por peso/volume (arroz, feijão, azeite...).
    public var unitWeightGrams: Double?

    public init(name: String, unit: PortionUnit = .g, per100: NutritionFacts, unitWeightGrams: Double? = nil) {
        self.name = name
        self.unit = unit
        self.per100 = per100
        self.unitWeightGrams = unitWeightGrams
    }
}

/// Base de referência com valores médios de alimentos comuns — pra quando
/// o usuário busca algo que ainda não cadastrou (roadmap: "linguiça, contra
/// filé, batata inglesa e etc"). Os números são médias públicas de
/// composição de alimentos (mesma família de referência da Tabela TACO/
/// USDA), não de um produto ou marca específica — por isso "valores
/// médios", editáveis depois de adicionados.
///
/// Fica no `ChefCore` (não em `Resources`/JSON externo) de propósito: é
/// dado estático, versionado junto do código, sem custo de I/O nem
/// dependência de rede — o app funciona sem internet mesmo quando a busca
/// online (`OpenFoodFactsService`, na camada do app) não responde.
public enum ReferenceFoodDatabase {
    public static func search(_ query: String) -> [ReferenceFood] {
        let normalized = normalizeText(query)
        guard !normalized.isEmpty else { return [] }
        return all
            .filter { normalizeText($0.name).contains(normalized) }
            .sorted { $0.name < $1.name }
    }

    /// Peso médio de 1 unidade de um alimento já conhecido, pelo nome —
    /// usado pra decidir se mostra a opção "por unidade" além de "por
    /// peso" ao adicionar o item (roadmap: "1,2,3 bifes ou 100,200,300
    /// gramas"). Casa pelo nome normalizado, então funciona tanto pra um
    /// `ReferenceFood` quanto pra um `SDFood` já materializado a partir
    /// de um — nenhum dos dois precisa guardar esse dado duplicado.
    public static func unitWeightGrams(forFoodNamed name: String) -> Double? {
        let normalized = normalizeText(name)
        return all.first { normalizeText($0.name) == normalized }?.unitWeightGrams
    }

    public static let all: [ReferenceFood] = [
        // MARK: Carnes e proteínas
        food("Linguiça", cal: 300, p: 13, c: 3, f: 27, unitG: 50),
        food("Contra filé grelhado", cal: 250, p: 26, c: 0, f: 16, unitG: 180),
        food("Peito de frango grelhado", cal: 165, p: 31, c: 0, f: 3.6, unitG: 150),
        food("Coxa de frango", cal: 209, p: 26, c: 0, f: 10.9, unitG: 90),
        food("Carne moída", cal: 215, p: 26, c: 0, f: 12),
        food("Picanha grelhada", cal: 289, p: 25, c: 0, f: 21, unitG: 200),
        food("Alcatra grelhada", cal: 200, p: 27, c: 0, f: 10, unitG: 180),
        food("Bacon", cal: 541, p: 37, c: 1.4, f: 42),
        food("Bisteca suína", cal: 231, p: 27, c: 0, f: 13, unitG: 150),
        food("Salmão grelhado", cal: 208, p: 20, c: 0, f: 13, unitG: 150),
        food("Tilápia grelhada", cal: 96, p: 20, c: 0, f: 1.7, unitG: 120),
        food("Atum em água", cal: 116, p: 26, c: 0, f: 1),
        food("Camarão", cal: 99, p: 24, c: 0.2, f: 0.3),
        food("Ovo cozido", cal: 155, p: 13, c: 1.1, f: 11, unitG: 50),
        food("Presunto", cal: 145, p: 21, c: 1.5, f: 5, unitG: 20),
        food("Mortadela", cal: 269, p: 12, c: 3, f: 24, unitG: 20),
        food("Peito de peru", cal: 135, p: 24, c: 3, f: 3, unitG: 100),
        food("Costela bovina", cal: 275, p: 24, c: 0, f: 19),
        food("Fígado bovino", cal: 135, p: 20, c: 3.9, f: 3.6),

        // MARK: Carboidratos
        food("Batata inglesa cozida", cal: 87, p: 1.9, c: 20, f: 0.1, unitG: 150),
        food("Batata doce cozida", cal: 86, p: 1.6, c: 20, f: 0.1, unitG: 150),
        food("Arroz branco cozido", cal: 130, p: 2.7, c: 28, f: 0.3),
        food("Arroz integral cozido", cal: 111, p: 2.6, c: 23, f: 0.9),
        food("Feijão carioca cozido", cal: 76, p: 4.8, c: 14, f: 0.5),
        food("Feijão preto cozido", cal: 77, p: 4.5, c: 14, f: 0.5),
        food("Macarrão cozido", cal: 131, p: 5, c: 25, f: 1.1),
        food("Pão francês", cal: 300, p: 8, c: 58, f: 3, unitG: 50),
        food("Pão de forma", cal: 266, p: 9, c: 49, f: 3.3, unitG: 25),
        food("Pão integral", cal: 247, p: 13, c: 41, f: 3.4, unitG: 30),
        food("Aveia em flocos", cal: 389, p: 17, c: 66, f: 7),
        food("Mandioca cozida", cal: 125, p: 0.6, c: 30, f: 0.3),
        food("Quinoa cozida", cal: 120, p: 4.4, c: 21, f: 1.9),
        food("Tapioca (goma hidratada)", cal: 240, p: 0.2, c: 59, f: 0),
        food("Milho cozido", cal: 96, p: 3.4, c: 21, f: 1.5),
        food("Cuscuz de milho", cal: 112, p: 2.5, c: 25, f: 0.3),

        // MARK: Vegetais e legumes
        food("Brócolis cozido", cal: 35, p: 2.4, c: 7, f: 0.4),
        food("Cenoura crua", cal: 41, p: 0.9, c: 10, f: 0.2, unitG: 60),
        food("Tomate", cal: 18, p: 0.9, c: 3.9, f: 0.2, unitG: 120),
        food("Alface", cal: 15, p: 1.4, c: 2.9, f: 0.2),
        food("Abobrinha", cal: 17, p: 1.2, c: 3.1, f: 0.3),
        food("Couve refogada", cal: 49, p: 3, c: 6, f: 2),
        food("Cebola", cal: 40, p: 1.1, c: 9.3, f: 0.1, unitG: 110),
        food("Pepino", cal: 15, p: 0.7, c: 3.6, f: 0.1),
        food("Pimentão", cal: 31, p: 1, c: 6, f: 0.3, unitG: 120),
        food("Beterraba cozida", cal: 44, p: 1.7, c: 10, f: 0.2),
        food("Vagem", cal: 31, p: 1.8, c: 7, f: 0.1),
        food("Abóbora cozida", cal: 26, p: 1, c: 6.5, f: 0.1),
        food("Repolho", cal: 25, p: 1.3, c: 5.8, f: 0.1),

        // MARK: Frutas
        food("Banana", cal: 89, p: 1.1, c: 23, f: 0.3, unitG: 100),
        food("Maçã", cal: 52, p: 0.3, c: 14, f: 0.2, unitG: 130),
        food("Laranja", cal: 47, p: 0.9, c: 12, f: 0.1, unitG: 150),
        food("Mamão", cal: 43, p: 0.5, c: 11, f: 0.3, unitG: 400),
        food("Abacate", cal: 160, p: 2, c: 8.5, f: 15, unitG: 200),
        food("Morango", cal: 32, p: 0.7, c: 7.7, f: 0.3, unitG: 15),
        food("Manga", cal: 60, p: 0.8, c: 15, f: 0.4, unitG: 200),
        food("Uva", cal: 69, p: 0.7, c: 18, f: 0.2),
        food("Melancia", cal: 30, p: 0.6, c: 8, f: 0.2),
        food("Abacaxi", cal: 50, p: 0.5, c: 13, f: 0.1),

        // MARK: Laticínios e ovos
        food("Leite integral", unit: .ml, cal: 61, p: 3.2, c: 4.8, f: 3.3),
        food("Leite desnatado", unit: .ml, cal: 35, p: 3.4, c: 5, f: 0.1),
        food("Iogurte natural", cal: 61, p: 3.5, c: 4.7, f: 3.3),
        food("Queijo minas", cal: 264, p: 17, c: 3, f: 20),
        food("Queijo mussarela", cal: 280, p: 22, c: 2.2, f: 21, unitG: 20),
        food("Requeijão", cal: 257, p: 9, c: 3, f: 23),
        food("Cottage", cal: 98, p: 11, c: 3.4, f: 4.3),

        // MARK: Grãos, sementes e outros
        food("Amendoim", cal: 567, p: 26, c: 16, f: 49),
        food("Castanha do pará", cal: 656, p: 14, c: 12, f: 66, unitG: 5),
        food("Amêndoas", cal: 579, p: 21, c: 22, f: 50),
        food("Azeite de oliva", unit: .ml, cal: 884, p: 0, c: 0, f: 100),
        food("Whey protein (pó)", cal: 400, p: 80, c: 8, f: 6),
        food("Pasta de amendoim", cal: 588, p: 25, c: 20, f: 50),
        food("Chocolate ao leite", cal: 535, p: 7.7, c: 59, f: 30),
        food("Mel", cal: 304, p: 0.3, c: 82, f: 0),
        food("Açúcar refinado", cal: 387, p: 0, c: 100, f: 0),
    ]

    private static func food(_ name: String, unit: PortionUnit = .g, cal: Double, p: Double, c: Double, f: Double, unitG: Double? = nil) -> ReferenceFood {
        ReferenceFood(name: name, unit: unit, per100: NutritionFacts(calories: cal, protein: p, carbs: c, fat: f), unitWeightGrams: unitG)
    }
}
