import Foundation

struct ScheduleDay: Codable, Equatable, Comparable {
    let rawValue: String

    init(containing date: Date, calendar: Calendar) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), (1...9999).contains(year),
              let month = Int(parts[1]), let day = Int(parts[2]) else {
            throw ScheduleValidationError(message: "The schedule contains an invalid effective date.")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: year, month: month, day: day) else {
            throw ScheduleValidationError(message: "The schedule contains an invalid effective date.")
        }
        rawValue = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct ScheduleRevision: Codable, Equatable {
    let effectiveFrom: ScheduleDay
    let blocks: [TimeBlock]
}

struct ScheduleHistory: Codable, Equatable {
    var baseline: [TimeBlock] = []
    var revisions: [ScheduleRevision] = []

    func blocks(on date: Date, calendar: Calendar) -> [TimeBlock] {
        let day = ScheduleDay(containing: date, calendar: calendar)
        return revisions.last(where: { $0.effectiveFrom <= day })?.blocks ?? baseline
    }

    func updating(_ blocks: [TimeBlock], from date: Date, calendar: Calendar) -> Self {
        let day = ScheduleDay(containing: date, calendar: calendar)
        var updated = self
        updated.revisions.removeAll { $0.effectiveFrom >= day }
        updated.revisions.append(ScheduleRevision(effectiveFrom: day, blocks: blocks))
        return updated
    }

    func validate() throws {
        try ScheduleValidation.validateAll(baseline)
        for (index, revision) in revisions.enumerated() {
            if index > 0, revisions[index - 1].effectiveFrom >= revision.effectiveFrom {
                throw ScheduleValidationError(message: "Schedule effective dates must be unique and in order.")
            }
            try ScheduleValidation.validateAll(revision.blocks)
        }
    }
}
