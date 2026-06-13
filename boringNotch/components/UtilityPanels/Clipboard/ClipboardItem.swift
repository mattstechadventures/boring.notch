//
//  ClipboardItem.swift
//  boringNotch
//
//  A captured pasteboard entry. Text/link items persist; image items are
//  session-only (NSImage is excluded from Codable, so they are not written).
//

import AppKit

enum ClipboardKind: String, Codable {
    case text
    case link
    case image
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let kind: ClipboardKind
    var text: String?
    /// Session-only — never encoded (see CodingKeys).
    var image: NSImage?
    let createdAt: Date

    init(id: UUID = UUID(),
         kind: ClipboardKind,
         text: String? = nil,
         image: NSImage? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.image = image
        self.createdAt = createdAt
    }

    /// Only text/link items survive a relaunch.
    var isPersistable: Bool { kind != .image }

    // `image` is intentionally omitted so NSImage is never (de)serialized.
    private enum CodingKeys: String, CodingKey {
        case id, kind, text, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(ClipboardKind.self, forKey: .kind) ?? .text
        text = try c.decodeIfPresent(String.self, forKey: .text)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        image = nil
    }

    /// One-line preview for the row.
    var preview: String {
        switch kind {
        case .image: return "Image"
        case .text, .link: return (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
