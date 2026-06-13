//
//  NotesViewModel.swift
//  boringNotch
//
//  @MainActor singleton over a CodableFileStore<NoteItem>. Persists on every
//  mutation. Newest note first.
//

import SwiftUI

@MainActor
final class NotesViewModel: ObservableObject {
    static let shared = NotesViewModel()

    @Published private(set) var notes: [NoteItem] = []

    private let store = CodableFileStore<NoteItem>(subdirectory: "Notes", filename: "notes.json")

    private init() {
        notes = store.load()
    }

    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.insert(NoteItem(body: trimmed), at: 0)
        persist()
    }

    func rename(_ note: NoteItem, to title: String) {
        mutate(note) {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.customTitle = trimmed.isEmpty ? nil : trimmed
            $0.updatedAt = Date()
        }
    }

    func updateBody(_ note: NoteItem, to body: String) {
        mutate(note) {
            $0.body = body
            $0.updatedAt = Date()
        }
    }

    func delete(_ note: NoteItem) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    func deleteAll() {
        notes.removeAll()
        persist()
    }

    /// Returns the current stored value for a note (e.g. after editing elsewhere).
    func current(_ note: NoteItem) -> NoteItem? {
        notes.first { $0.id == note.id }
    }

    private func mutate(_ note: NoteItem, _ change: (inout NoteItem) -> Void) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        change(&notes[idx])
        persist()
    }

    private func persist() {
        store.save(notes)
    }
}
