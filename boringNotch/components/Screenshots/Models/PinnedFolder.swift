import Foundation
import Defaults

struct PinnedFolder: Codable, Hashable, Equatable, Sendable, Identifiable, Defaults.Serializable {
    let id: UUID
    var displayName: String
    let bookmark: Data

    init(id: UUID = UUID(), displayName: String, bookmark: Data) {
        self.id = id
        self.displayName = displayName
        self.bookmark = bookmark
    }
}
