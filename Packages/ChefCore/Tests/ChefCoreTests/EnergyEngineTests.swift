import XCTest
@testable import ChefCore

final class EnergyEngineTests: XCTestCase {
    /// Caso de referência conferido na mão: homem, 120 kg, 180 cm, 29 anos.
    /// 10×120 + 6.25×180 − 5×29 + 5 = 1200 + 1125 − 145 + 5 = 2185
    func testMifflinStJeorMale() {
        let metrics = BodyMetrics(weightKg: 120, heightCm: 180, age: 29, sex: .male)
        XCTAssertEqual(EnergyEngine.basalMetabolicRate(for: metrics), 2185)
    }

    /// Mesmas medidas, constante feminina: 2185 − 5 − 161 = 2019
    func testMifflinStJeorFemale() {
        let metrics = BodyMetrics(weightKg: 120, heightCm: 180, age: 29, sex: .female)
        XCTAssertEqual(EnergyEngine.basalMetabolicRate(for: metrics), 2019)
    }

    func testUnspecifiedSexFallsBetweenTheTwoConstants() throws {
        let male = try XCTUnwrap(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 80, heightCm: 175, age: 30, sex: .male)
        ))
        let female = try XCTUnwrap(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 80, heightCm: 175, age: 30, sex: .female)
        ))
        let unspecified = try XCTUnwrap(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 80, heightCm: 175, age: 30, sex: .unspecified)
        ))

        XCTAssertLessThan(female, unspecified)
        XCTAssertLessThan(unspecified, male)
    }

    /// Sem medida não existe estimativa — devolve nil em vez de chutar um
    /// número, mesma regra do scanner (não encontrado ≠ zero).
    func testIncompleteMetricsReturnNil() {
        XCTAssertNil(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 0, heightCm: 180, age: 29)
        ))
        XCTAssertNil(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 80, heightCm: 0, age: 29)
        ))
        XCTAssertNil(EnergyEngine.basalMetabolicRate(
            for: BodyMetrics(weightKg: 80, heightCm: 180, age: 0)
        ))
        XCTAssertNil(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 80, heightCm: 180, age: 0)
        ))
    }

    func testActivityLevelRaisesTotalExpenditureAboveBasal() throws {
        let sedentary = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 90, heightCm: 178, age: 35, sex: .male, activity: .sedentary)
        ))
        let active = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 90, heightCm: 178, age: 35, sex: .male, activity: .active)
        ))

        XCTAssertGreaterThan(sedentary.totalEnergyExpenditure, sedentary.basalMetabolicRate)
        XCTAssertGreaterThan(active.totalEnergyExpenditure, sedentary.totalEnergyExpenditure)
        XCTAssertEqual(sedentary.basalMetabolicRate, active.basalMetabolicRate)
    }

    func testObjectiveAppliesDeficitAndSurplus() throws {
        func targets(_ objective: WeightObjective) throws -> EnergyTargets {
            try XCTUnwrap(EnergyEngine.calculateTargets(
                for: BodyMetrics(weightKg: 90, heightCm: 178, age: 35, sex: .male, activity: .moderate, objective: objective)
            ))
        }

        let lose = try targets(.lose)
        let maintain = try targets(.maintain)
        let gain = try targets(.gain)

        XCTAssertLessThan(lose.calories, maintain.calories)
        XCTAssertGreaterThan(gain.calories, maintain.calories)
        // Manter = o próprio GET, sem ajuste.
        XCTAssertEqual(maintain.calories, (maintain.totalEnergyExpenditure / 10).rounded() * 10, accuracy: 0.01)
    }

    /// Os macros têm que fechar com a meta calórica, senão o usuário vê
    /// números que não somam.
    func testMacrosAddUpToTheCalorieTarget() throws {
        let targets = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 120, heightCm: 180, age: 29, sex: .male, activity: .light, objective: .lose)
        ))

        let fromMacros = targets.protein * 4 + targets.carbs * 4 + targets.fat * 9
        // Tolerância de 25 kcal por causa dos arredondamentos pra grama
        // inteira e pra dezena de kcal.
        XCTAssertEqual(fromMacros, targets.calories, accuracy: 25)
    }

    func testProteinFollowsBodyWeightAndObjective() throws {
        let losing = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 100, heightCm: 180, age: 30, sex: .male, objective: .lose)
        ))
        let maintaining = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 100, heightCm: 180, age: 30, sex: .male, objective: .maintain)
        ))

        XCTAssertEqual(losing.protein, 180)      // 100 kg × 1.8
        XCTAssertEqual(maintaining.protein, 160) // 100 kg × 1.6
    }

    func testWaterAndFiberFollowTheirReferences() throws {
        let targets = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 80, heightCm: 175, age: 30, sex: .male, activity: .sedentary, objective: .maintain)
        ))

        XCTAssertEqual(targets.water, 2800)  // 80 kg × 35 ml
        XCTAssertEqual(targets.fiber, (targets.calories / 1000 * 14).rounded())
    }

    func testTargetsConvertToDailyGoal() throws {
        let targets = try XCTUnwrap(EnergyEngine.calculateTargets(
            for: BodyMetrics(weightKg: 80, heightCm: 175, age: 30, sex: .male)
        ))
        let goal = targets.asDailyGoal

        XCTAssertEqual(goal.calories, targets.calories)
        XCTAssertEqual(goal.protein, targets.protein)
        XCTAssertEqual(goal.water, targets.water)
    }
}
