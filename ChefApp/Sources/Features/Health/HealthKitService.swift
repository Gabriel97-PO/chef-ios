import Foundation
import HealthKit
import SwiftData
import ChefCore

/// Integração com o Apple Saúde (roadmap item 2 — e, por consequência, o
/// item 3).
///
/// Sobre balança de bioimpedância: não existe integração direta com marca
/// nenhuma, e não precisa. Withings, Xiaomi, Renpho, Omron e afins escrevem
/// peso e percentual de gordura no Apple Saúde; lendo daqui, qualquer
/// balança que o usuário já tenha passa a alimentar o Chef.
///
/// Direção dos dados, de propósito:
/// - **lê** peso e gordura corporal (a balança é a fonte da verdade);
/// - **escreve** o que foi consumido (o Chef é a fonte da verdade do que
///   entrou na boca).
///
/// Nunca sobrescreve um registro de peso que já existe no Chef: importar é
/// só preencher os dias que estão vazios.
@MainActor
enum HealthKitService {
    enum ServiceError: LocalizedError {
        case unavailable
        case notAuthorized(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "O Apple Saúde não está disponível neste dispositivo."
            case .notAuthorized(let detail):
                return detail
            }
        }
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let store = HKHealthStore()

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let mass = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(mass) }
        if let fat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(fat) }
        return types
    }

    private static var writeTypes: Set<HKSampleType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietaryWater,
        ]
        return Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    static func requestAuthorization() async throws {
        guard isAvailable else { throw ServiceError.unavailable }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        } catch {
            // O erro mais comum aqui é entitlement de HealthKit ausente, que
            // depende de conta paga da Apple. Repassamos a mensagem real em
            // vez de engolir e mostrar "algo deu errado".
            throw ServiceError.notAuthorized(error.localizedDescription)
        }
    }

    // MARK: - Leitura: peso vindo da balança

    /// Traz os pesos do Apple Saúde dos últimos `days` dias e grava no Chef
    /// os dias que ainda não têm registro. Devolve quantos dias entraram.
    @discardableResult
    static func importWeights(days: Int = 90, into context: ModelContext) async throws -> Int {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw ServiceError.unavailable
        }

        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let samples = try await quantitySamples(type: type, from: start)

        // Um dia pode ter várias pesagens; fica a última de cada dia.
        var latestByDay: [String: HKQuantitySample] = [:]
        for sample in samples {
            let key = DateKey.string(from: sample.startDate)
            if let existing = latestByDay[key], existing.startDate > sample.startDate { continue }
            latestByDay[key] = sample
        }

        let alreadyLogged = Set(WeightStore.all(in: context).map(\.date))
        var imported = 0

        for (key, sample) in latestByDay where !alreadyLogged.contains(key) {
            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            context.insert(SDWeightEntry(date: key, weightKg: (kg * 10).rounded() / 10))
            imported += 1
        }

        if imported > 0 { try? context.save() }
        return imported
    }

    /// Último percentual de gordura corporal medido pela balança, se houver.
    static func latestBodyFatPercentage() async throws -> Double? {
        guard isAvailable, let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            return nil
        }
        let start = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let samples = try await quantitySamples(type: type, from: start)
        guard let latest = samples.max(by: { $0.startDate < $1.startDate }) else { return nil }
        return latest.quantity.doubleValue(for: .percent()) * 100
    }

    // MARK: - Escrita: consumo do dia

    /// Exporta o consumo de um dia pro Apple Saúde. Substitui o que o Chef
    /// já tinha escrito naquele dia, pra não dobrar valores quando o usuário
    /// exporta duas vezes — e sem tocar no que outros apps escreveram.
    static func exportConsumption(
        _ nutrition: NutritionFacts,
        waterMl: Double?,
        on dateKey: String
    ) async throws {
        guard isAvailable else { throw ServiceError.unavailable }
        guard let day = DateKey.date(from: dateKey) else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day

        var samples: [HKQuantitySample] = []

        func add(_ identifier: HKQuantityTypeIdentifier, _ value: Double?, _ unit: HKUnit) {
            guard let value, value > 0, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
            samples.append(
                HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(unit: unit, doubleValue: value),
                    start: start,
                    end: end
                )
            )
        }

        add(.dietaryEnergyConsumed, nutrition.calories, .kilocalorie())
        add(.dietaryProtein, nutrition.protein, .gram())
        add(.dietaryCarbohydrates, nutrition.carbs, .gram())
        add(.dietaryFatTotal, nutrition.fat, .gram())
        add(.dietaryFiber, nutrition.fiber, .gram())
        add(.dietaryWater, waterMl, .literUnit(with: .milli))

        guard !samples.isEmpty else { return }

        try await deletePreviouslyExported(from: start, to: end)
        try await store.save(samples)
    }

    private static func deletePreviouslyExported(from start: Date, to end: Date) async throws {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        // Só o que este app escreveu — o predicado de source limita ao
        // próprio bundle, então dado de outro app nunca é apagado.
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let combined = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sourcePredicate])

        for type in writeTypes.compactMap({ $0 as? HKQuantityType }) {
            _ = try? await store.deleteObjects(of: type, predicate: combined)
        }
    }

    // MARK: - Infra

    private static func quantitySamples(type: HKQuantityType, from start: Date) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(withStart: start, end: Date()),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }
}
