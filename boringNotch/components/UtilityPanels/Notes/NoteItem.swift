//
//  NoteItem.swift
//  boringNotch
//
//  A single local note. `source` is a seam for future sync providers
//  (Notion / watched plain-text); Phase 1 is `.local` only.
//

import Foundation

enum NoteSource: String, Codable {
    case local
}

struct NoteItem: Identifiable, Codable, Equatable {
    let id: UUID
    /// User-set title; when nil/empty the title is derived from the first line.
    var customTitle: String?
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var source: NoteSource

    init(id: UUID = UUID(),
         customTitle: String? = nil,
         body: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         source: NoteSource = .local) {
        self.id = id
        self.customTitle = customTitle
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }

    /// Displayed title: explicit `customTitle`, else first line of the body.
    var title: String {
        if let custom = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return body.titleFromFirstLine()
    }

    private enum CodingKeys: String, CodingKey {
        case id, customTitle, body, createdAt, updatedAt, source
    }

    // Tolerant decode so adding fields later never wipes saved notes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        customTitle = try c.decodeIfPresent(String.self, forKey: .customTitle)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        source = try c.decodeIfPresent(NoteSource.self, forKey: .source) ?? .local
    }
}
