import Foundation

struct ScheduleFile: Codable {
    let version: Int
    let baseline: [TimeBlock]
    let revisions: [ScheduleRevision]

    var history: ScheduleHistory { ScheduleHistory(baseline: baseline, revisions: revisions) }

    init(history: ScheduleHistory) {
        version = 2
        baseline = history.baseline
        revisions = history.revisions
    }

    private enum CodingKeys: String, CodingKey {
        case version, blocks, baseline, revisions
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        switch version {
        case 1:
            baseline = try values.decode([TimeBlock].self, forKey: .blocks)
            revisions = []
        case 2:
            baseline = try values.decode([TimeBlock].self, forKey: .baseline)
            revisions = try values.decode([ScheduleRevision].self, forKey: .revisions)
        default:
            throw ScheduleValidationError(message: "This schedule version is not supported.")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(2, forKey: .version)
        try values.encode(baseline, forKey: .baseline)
        try values.encode(revisions, forKey: .revisions)
    }
}

struct ScheduleStore {
    let url: URL

    init() {
        let identifier = Bundle.main.bundleIdentifier ?? "io.github.zxhio.daycue"
        url = URL.applicationSupportDirectory.appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("schedule.json")
    }

    func load() throws -> ScheduleHistory {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return ScheduleHistory()
        }
        let file = try JSONDecoder().decode(ScheduleFile.self, from: data)
        try file.history.validate()
        func normalized(_ blocks: [TimeBlock]) -> [TimeBlock] {
            blocks.map {
                var block = $0
                block.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return block
            }
        }
        let history = ScheduleHistory(
            baseline: normalized(file.baseline),
            revisions: file.revisions.map { ScheduleRevision(effectiveFrom: $0.effectiveFrom, blocks: normalized($0.blocks)) }
        )
        if file.version == 1 {
            let backup = url.deletingLastPathComponent().appendingPathComponent("schedule-v1-backup-\(UUID().uuidString).json")
            try data.write(to: backup, options: .withoutOverwriting)
            try save(history)
        }
        return history
    }

    func save(_ history: ScheduleHistory) throws {
        try history.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ScheduleFile(history: history))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
