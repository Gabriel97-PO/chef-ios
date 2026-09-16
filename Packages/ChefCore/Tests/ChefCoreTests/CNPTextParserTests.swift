import XCTest
@testable import ChefCore

final class CNPTextParserTests: XCTestCase {

    func testUsesJsonDocumentDirectlyWhenPastedTextIsValidCnp() throws {
        let json = """
        {
          "protocol": "chef-nutrition",
          "version": "1.0",
          "patient": { "name": "Gabriel" },
          "goals": { "calories": 2100, "protein_g": 170 },
          "meals": [ { "name": "Almoço", "foods": [ { "name": "Arroz", "quantity": 150, "unit": "g" } ] } ]
        }
        """
        let result = CNPTextParser.parse(text: json)
        XCTAssertEqual(result.document.patient.name, "Gabriel")
        XCTAssertTrue(result.summary.foundCalorieGoal)
        XCTAssertEqual(result.summary.mealCount, 1)
    }

    func testExtractsPatientGoalsAndMealsFromStructuredText() throws {
        let text = [
            "PACIENTE: Gabriel", "",
            "CALORIAS: 2100", "PROTEÍNA: 170", "",
            "ALMOÇO", "150 g arroz", "200 g peito de frango", "OU", "200 g batata doce",
        ].joined(separator: "\n")

        let result = CNPTextParser.parse(text: text)

        XCTAssertEqual(result.document.patient.name, "Gabriel")
        XCTAssertEqual(result.document.goals.calories, 2100)
        XCTAssertEqual(result.document.goals.proteinG, 170)
        XCTAssertTrue(result.summary.foundCalorieGoal)
        XCTAssertTrue(result.summary.foundProteinGoal)

        let meal = try XCTUnwrap(result.document.meals.first)
        XCTAssertTrue(normalizeText(meal.name).contains("almoco") || normalizeText(meal.name).contains("almoço"))
        XCTAssertTrue(meal.foods.contains { $0.name == "arroz" })
    }

    func testTreatsOuSeparatedFoodsAsSubstitutionGroupNeverAsFixedItems() throws {
        let text = ["ALMOÇO", "200 g peito de frango", "OU", "200 g batata doce"].joined(separator: "\n")
        let result = CNPTextParser.parse(text: text)
        let meal = try XCTUnwrap(result.document.meals.first)

        XCTAssertEqual(meal.substitutions?.count, 1)
        XCTAssertEqual(meal.substitutions?.first?.options.map(\.name), ["peito de frango", "batata doce"])
        XCTAssertFalse(meal.foods.contains { $0.name == "peito de frango" })
    }

    func testReportsUnrecognizedLineAsAmbiguityNeverDiscardsSilently() {
        let text = ["ALMOÇO", "150 g arroz", "levar embalagem para reciclagem"].joined(separator: "\n")
        let result = CNPTextParser.parse(text: text)
        XCTAssertTrue(result.summary.ambiguities.contains("levar embalagem para reciclagem"))
    }

    func testNeverInventsAGoalThatWasNotFoundInText() {
        let text = ["PACIENTE: Gabriel", "", "ALMOÇO", "150 g arroz"].joined(separator: "\n")
        let result = CNPTextParser.parse(text: text)
        XCTAssertFalse(result.summary.foundCalorieGoal)
        XCTAssertEqual(result.document.goals.calories, 0)
    }
}
