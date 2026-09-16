import XCTest
@testable import ChefCore

final class ConfidenceTests: XCTestCase {
    func testHighConfidence() {
        XCTAssertEqual(confidenceTier(0.96), .high)
        XCTAssertEqual(confidenceTier(0.85), .high)
    }

    func testReviewConfidence() {
        XCTAssertEqual(confidenceTier(0.6), .review)
        XCTAssertEqual(confidenceTier(0.5), .review)
    }

    func testUnrecognizedConfidence() {
        XCTAssertEqual(confidenceTier(0.2), .unrecognized)
    }

    func testMissingFieldIsNeverTreatedAsZero() {
        XCTAssertEqual(confidenceTier(nil), .unrecognized)
    }
}
