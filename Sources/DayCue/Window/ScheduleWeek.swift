import Foundation

struct ScheduleDate: Identifiable {
    let date: Date
    let weekday: Weekday
    let dayNumber: Int
    var id: Date { date }
}

struct ScheduleWeek {
    let selectedDate: Date
    let calendar: Calendar

    init(containing date: Date, calendar: Calendar) {
        self.calendar = calendar
        selectedDate = calendar.startOfDay(for: date)
    }

    private var start: Date {
        let offset = (calendar.component(.weekday, from: selectedDate) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
    }

    var days: [ScheduleDate] {
        Weekday.allCases.enumerated().compactMap { offset, weekday in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ScheduleDate(date: date, weekday: weekday, dayNumber: calendar.component(.day, from: date))
        }
    }

    var selectedWeekday: Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: selectedDate)) ?? .monday
    }

    var rangeTitle: String {
        guard let end = days.last?.date else { return "" }
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let startFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        let endFormat = sameYear && sameMonth ? "d, yyyy" : "MMM d, yyyy"
        return "\(format(start, as: startFormat)) – \(format(end, as: endFormat))"
    }

    var selectedTitle: String { format(selectedDate, as: "EEEE, MMMM d") }

    func label(for date: Date) -> String { format(date, as: "EEEE, MMMM d, yyyy") }

    func moving(by weeks: Int) -> Date? {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDate)
    }

    private func format(_ date: Date, as pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
