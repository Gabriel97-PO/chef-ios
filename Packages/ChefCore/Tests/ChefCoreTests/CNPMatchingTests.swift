import XCTest
@testable import ChefCore

final class CNPMatchingTests: XCTestCase {
    private var baseDocument: CnpDocument {
        CnpDocument(
            patient: CnpPatient(name: "Gabriel"),
            goals: CnpGoals(calories: 2100, proteinG: 170),
            meals: [
                CnpMeal(
                    name: "Almoço",
                    foods: [CnpFoodItem(name: "Arroz branco", quantity: 150, unit: .g)],
                    substitutions: [
                        CnpSubstitutionGroup(group: "peito de frango", options: [
                            CnpFoodItem(name: "Peito de frango", quantity: 200, unit: .g),
                            CnpFoodItem(name: "Carne moída", quantity: 200, unit: .g),
                        ])
                    ]
                )
            ]
        )
    }

    func testFindsDirectFoodInMeal() {
        let match = CNPMatching.findPrescribedMatch(in: baseDocument, foodName: "Arroz branco cozido")
        XCTAssertEqual(match?.name, "Arroz branco")
    }

    func testFindsFoodInsideSubstitutionGroupNeverAMissedMatch() {
        let match = CNPMatching.findPrescribedMatch(in: baseDocument, foodName: "Carne moída (patinho)")
        XCTAssertEqual(match?.name, "Carne moída")
    }

    func testReturnsNilWhenProductIsNotInTheDiet() {
        XCTAssertNil(CNPMatching.findPrescribedMatch(in: baseDocument, foodName: "Refrigerante de cola"))
    }

    func testHasPrescribedFoodsTrueWhenAtLeastOneExists() {
        XCTAssertTrue(CNPMatching.hasPrescribedFoods(baseDocument))
    }

    func testHasPrescribedFoodsFalseForEmptyDiet() {
        var empty = baseDocument
        empty.meals = []
        XCTAssertFalse(CNPMatching.hasPrescribedFoods(empty))
    }

    func testResolvedFoodsNeverSilentlyDropsASubstitutionGroup() {
        let meal = baseDocument.meals[0]
        let resolved = CNPMatching.resolvedFoods(for: meal)
        XCTAssertEqual(resolved.map(\.name), ["Arroz branco", "Peito de frango"])
    }
}
