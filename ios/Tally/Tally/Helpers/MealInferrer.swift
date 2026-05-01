import Foundation

enum MealInferrer {

    /// Returns the meal name for a given minute-of-day (hour * 60 + min).
    /// Ranges match `app/services/meal_inferrer.rb` exactly.
    static func meal(at minuteOfDay: Int) -> String {
        switch minuteOfDay {
        case (4 * 60)..<(10 * 60 + 30):
            return "breakfast"
        case (10 * 60 + 30)..<(14 * 60 + 30):
            return "lunch"
        case (14 * 60 + 30)..<(17 * 60 + 30):
            return "snacks"
        case (17 * 60 + 30)..<(21 * 60 + 30):
            return "dinner"
        default:
            return "snacks"
        }
    }

    /// Returns the meal name for the current time in the user's local timezone.
    static func current() -> String {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minuteOfDay = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return meal(at: minuteOfDay)
    }
}
