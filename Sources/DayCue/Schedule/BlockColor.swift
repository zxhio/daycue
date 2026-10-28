import Foundation

enum BlockColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case gray, blue, red, yellow, green, pink, purple, teal, orange

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        let name = try value.decode(String.self)
        switch name {
        case "softBlue": self = .blue
        case "softViolet", "violet": self = .purple
        case "softJade", "jade": self = .green
        case "softAmber", "amber": self = .yellow
        case "rose": self = .pink
        case "cyan": self = .teal
        case "slate": self = .gray
        default:
            guard let color = Self(rawValue: name) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unknown time block color.")
            }
            self = color
        }
    }
}
