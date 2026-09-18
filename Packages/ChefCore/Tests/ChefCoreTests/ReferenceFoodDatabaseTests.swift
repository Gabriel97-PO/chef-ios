import XCTest
@testable import ChefCore

final class ReferenceFoodDatabaseTests: XCTestCase {
    func testFindsCommonFoodsMentionedByTheUser() {
        XCTAssertFalse(ReferenceFoodDatabase.search("linguiça").isEmpty)
        XCTAssertFalse(ReferenceFoodDatabase.search("contra file").isEmpty) // sem acento
        XCTAssertFalse(ReferenceFoodDatabase.search("batata inglesa").isEmpty)
    }

    func testSearchIsAccentAndCaseInsensitive() {
        XCTAssertEqual(ReferenceFoodDatabase.search("ovo"), ReferenceFoodDatabase.search("OVO"))
        XCTAssertFalse(ReferenceFoodDatabase.search("mac").isEmpty) // "Maçã"
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(ReferenceFoodDatabase.search("").isEmpty)
    }

    func testEveryEntryHasPositiveCalories() {
        for item in ReferenceFoodDatabase.all {
            XCTAssertGreaterThan(item.per100.calories, 0, item.name)
        }
    }

    func testNoDuplicateNames() {
        let names = ReferenceFoodDatabase.all.map(\.name)
        XCTAssertEqual(names.count, Set(names).count)
    }
}
