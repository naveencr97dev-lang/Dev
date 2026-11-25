import XCTest
@testable import CoreTests

fileprivate extension GuideTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__GuideTests = [
        ("testCleanChecklistExists", testCleanChecklistExists),
        ("testEveryRobberyHasStepsAndEveryTierIsUsed", testEveryRobberyHasStepsAndEveryTierIsUsed),
        ("testIdsUnique", testIdsUnique),
        ("testPrepOnlyForWalkInTargets", testPrepOnlyForWalkInTargets)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __CoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(GuideTests.__allTests__GuideTests)
    ]
}