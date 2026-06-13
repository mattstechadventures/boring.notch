//
//  NotchTask.swift
//  boringNotch
//
//  A single local checklist item. `source` is the Phase-2 connector seam
//  (Todoist / Outlook / Scoro); Phase 1 is `.local` only.
//

import Foundation

enum TaskSource: String, Codable {
    case local
}

struct NotchTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
    var source: TaskSource

    init(id: UUID = UUID(),
         title: String,
         isDone: Bool = false,
         createdAt: Date = Date(),
         source: TaskSource = .local) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isDone, createdAt, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        source = try c.decodeIfPresent(TaskSource.self, forKey: .source) ?? .local
    }
}
