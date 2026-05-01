import XCTest
@testable import Tally

final class MealInferrerTests: XCTestCase {

    func testEarlyMorningIsBreakfast() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 7, min: 0)), "breakfast")
    }

    func testBoundary0400IsBreakfast() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 4, min: 0)), "breakfast")
    }

    func testBoundary1030FlipsToLunch() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 10, min: 30)), "lunch")
    }

    func testAfternoonIsSnacks() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 15, min: 0)), "snacks")
    }

    func testEveningIsDinner() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 19, min: 0)), "dinner")
    }

    func testLateNightIsSnacks() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 23, min: 0)), "snacks")
    }

    func testAfterMidnightIsSnacks() {
        XCTAssertEqual(MealInferrer.meal(at: minuteOfDay(hour: 1, min: 30)), "snacks")
    }

    func testCurrentReturnsAValidMeal() {
        let validMeals = ["breakfast", "lunch", "snacks", "dinner"]
        XCTAssertTrue(validMeals.contains(MealInferrer.current()))
    }

    // MARK: - Helpers

    private func minuteOfDay(hour: Int, min: Int) -> Int {
        hour * 60 + min
    }
}
