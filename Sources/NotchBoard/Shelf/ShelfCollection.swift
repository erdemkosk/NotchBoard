import SwiftUI

/// A named, colored tab on the shelf that groups parked files together
/// (e.g. "Design", "Work", "Temp").
struct ShelfCollection: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    /// Hex string (e.g. "#34C759") used to tint the tab's dot.
    var colorHex: String
    let createdAt: Date
    var isLocked: Bool = false

    init(id: UUID = UUID(), name: String, colorHex: String, createdAt: Date = Date(), isLocked: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isLocked = isLocked
    }

    enum CodingKeys: CodingKey {
        case id, name, colorHex, createdAt, isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isLocked, forKey: .isLocked)
    }

    var color: Color {
        Color(nsColor: NSColor(hex: colorHex) ?? .systemBlue)
    }

    /// Palette offered when creating or recoloring a collection.
    static let palette: [String] = [
        "#34C759", "#0A84FF", "#FF9F0A", "#FF375F",
        "#BF5AF2", "#5AC8FA", "#FFD60A", "#8E8E93"
    ]

    static func makeDefault(name: String) -> ShelfCollection {
        ShelfCollection(name: name, colorHex: palette[1])
    }
}
