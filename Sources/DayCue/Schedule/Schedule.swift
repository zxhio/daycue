import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable, Comparable {
    case monday = 2, tuesday, wednesday, thursday, friday, saturday, sunday = 1

    var id: Int { rawValue }
    var shortName: String { String(name.prefix(3)) }
    var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
    private var order: Int { (rawValue + 5) % 7 }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}

struct TimeBlock: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var startMinute: Int
    var endMinute: Int
    var days: Set<Weekday>
    var color: BlockColor = .blue

    var timeRange: String { "\(MinuteTime.format(startMinute)) - \(MinuteTime.format(endMinute))" }
}

extension TimeBlock {
    private enum CodingKeys: String, CodingKey {
        case id, name, startMinute, endMinute, days, color
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        startMinute = try values.decode(Int.self, forKey: .startMinute)
        endMinute = try values.decode(Int.self, forKey: .endMinute)
        days = try values.decode(Set<Weekday>.self, forKey: .days)
        color = try values.decodeIfPresent(BlockColor.self, forKey: .color) ?? .blue
    }
}

struct MinuteRange {
    let start: Int
    let end: Int

    var text: String { "\(MinuteTime.format(start)) - \(MinuteTime.format(end))" }

    static func parse(_ text: String) -> Self? {
        let parts = text.replacingOccurrences(of: "–", with: "-").split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let start = MinuteTime.parse(parts[0].trimmingCharacters(in: .whitespacesAndNewlines), allowMidnight: false),
              let end = MinuteTime.parse(parts[1].trimmingCharacters(in: .whitespacesAndNewlines), allowMidnight: true) else { return nil }
        return Self(start: start, end: end)
    }
}

enum MinuteTime {
    static func format(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    static func parse(_ text: String, allowMidnight: Bool) -> Int? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]), minute < 60 else { return nil }
        if allowMidnight && hour == 24 && minute == 0 { return 1440 }
        guard hour < 24 else { return nil }
        return hour * 60 + minute
    }
}

struct ScheduleValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ScheduleValidation {
    static func validate(_ block: TimeBlock, among blocks: [TimeBlock]) throws {
        guard !block.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScheduleValidationError(message: "Enter a name.")
        }
        guard (0...1439).contains(block.startMinute), (1...1440).contains(block.endMinute),
              block.endMinute > block.startMinute else {
            throw ScheduleValidationError(message: "End time must be after start time.")
        }
        guard !block.days.isEmpty else {
            throw ScheduleValidationError(message: "Select at least one day.")
        }
        for day in block.days.sorted() {
            if let conflict = blocks.first(where: {
                $0.id != block.id && $0.days.contains(day) && block.startMinute < $0.endMinute && $0.startMinute < block.endMinute
            }) {
                throw ScheduleValidationError(message: "This time block overlaps with “\(conflict.name)” on \(day.name).")
            }
        }
    }

    static func validateAll(_ blocks: [TimeBlock]) throws {
        guard Set(blocks.map(\.id)).count == blocks.count else {
            throw ScheduleValidationError(message: "The schedule contains duplicate time blocks.")
        }
        for block in blocks { try validate(block, among: blocks) }
    }
}

struct BlockOccurrence: Equatable {
    let block: TimeBlock
    let day: Date
}

struct ScheduleSnapshot: Equatable {
    let current: BlockOccurrence?
    let next: TimeBlock?
    var title: String { current?.block.name ?? "Free Time" }
}

struct ScheduleBoundary {
    let date: Date
    let isClockChange: Bool
}

enum ScheduleCalculation {
    static func blocks(on day: Weekday, in blocks: [TimeBlock]) -> [TimeBlock] {
        blocks.filter { $0.days.contains(day) }.sorted { $0.startMinute < $1.startMinute }
    }

    static func snapshot(at date: Date, calendar: Calendar, blocks: [TimeBlock]) -> ScheduleSnapshot {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday.flatMap(Weekday.init(rawValue:)),
              let hour = components.hour, let minute = components.minute else {
            return ScheduleSnapshot(current: nil, next: nil)
        }
        let now = hour * 60 + minute
        let today = self.blocks(on: weekday, in: blocks)
        let current = today.first { $0.startMinute <= now && now < $0.endMinute }
        let start = calendar.startOfDay(for: date)
        var next: TimeBlock?
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) {
            var nextDate = tomorrow
            for block in today {
                for candidate in boundaryDates(minute: block.startMinute, day: start, calendar: calendar)
                    where candidate > date && candidate < nextDate {
                    next = block
                    nextDate = candidate
                }
            }
        }
        return ScheduleSnapshot(
            current: current.map { BlockOccurrence(block: $0, day: start) },
            next: next
        )
    }

    static func nextBoundary(after date: Date, calendar: Calendar, blocks: [TimeBlock]) -> ScheduleBoundary? {
        let start = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: start),
              let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) else { return nil }
        var result = ScheduleBoundary(date: tomorrow, isClockChange: false)
        let minutes = Set(self.blocks(on: weekday, in: blocks).flatMap { [$0.startMinute, $0.endMinute] })
        for minute in minutes where minute < 1440 {
            for boundary in boundaryDates(minute: minute, day: start, calendar: calendar)
                where boundary > date && boundary < result.date {
                result = ScheduleBoundary(date: boundary, isClockChange: false)
            }
        }
        if let transition = calendar.timeZone.nextDaylightSavingTimeTransition(after: date), transition <= result.date {
            result = ScheduleBoundary(date: transition, isClockChange: true)
        }
        return result
    }

    private static func boundaryDates(minute: Int, day: Date, calendar: Calendar) -> [Date] {
        let match = DateComponents(hour: minute / 60, minute: minute % 60, second: 0)
        return [Calendar.RepeatedTimePolicy.first, .last].compactMap { policy in
            calendar.nextDate(after: day.addingTimeInterval(-1), matching: match,
                              matchingPolicy: .strict, repeatedTimePolicy: policy)
        }
    }
}
