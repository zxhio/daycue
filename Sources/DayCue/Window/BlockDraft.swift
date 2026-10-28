import Foundation
import Combine

@MainActor
final class BlockDraft: ObservableObject {
    @Published var name: String
    @Published var timeRange: String
    @Published var days: Set<Weekday>
    @Published var color: BlockColor
    @Published var error: String?
    @Published var isSaving = false
    let id: UUID
    let original: TimeBlock?
    private let initialName: String
    private let initialTimeRange: String
    private let initialDays: Set<Weekday>

    init(block: TimeBlock?, day: Weekday) {
        original = block
        id = block?.id ?? UUID()
        initialName = block?.name ?? ""
        initialTimeRange = block?.timeRange ?? "09:00 - 10:00"
        initialDays = block?.days ?? [day]
        name = initialName
        timeRange = initialTimeRange
        days = initialDays
        color = block?.color ?? .blue
    }

    var hasChanges: Bool {
        name != initialName || timeRange != initialTimeRange || days != initialDays || color != (original?.color ?? .blue)
    }

    func block(among blocks: [TimeBlock]) throws -> TimeBlock {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ScheduleValidationError(message: "Enter a name.") }
        guard let range = MinuteRange.parse(timeRange) else {
            throw ScheduleValidationError(message: "Use HH:mm - HH:mm. Only the end time allows 24:00.")
        }
        let block = TimeBlock(id: id, name: trimmedName, startMinute: range.start, endMinute: range.end, days: days, color: color)
        try ScheduleValidation.validate(block, among: blocks)
        return block
    }
}
