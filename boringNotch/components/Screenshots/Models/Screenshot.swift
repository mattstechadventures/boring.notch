import AppKit
import Foundation

struct Screenshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let addedAt: Date
    let byteSize: Int64

    init(id: UUID = UUID(), url: URL, addedAt: Date, byteSize: Int64) {
        self.id = id
        self.url = url
        self.addedAt = addedAt
        self.byteSize = byteSize
    }
}
