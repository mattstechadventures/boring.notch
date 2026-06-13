//
//  NoteDetailView.swift
//  boringNotch
//
//  Inline note editor: editable title + body. Commits on back / disappear.
//

import SwiftUI

struct NoteDetailView: View {
    let note: NoteItem
    let onBack: () -> Void

    @ObservedObject private var vm = NotesViewModel.shared
    @State private var titleDraft: String
    @State private var bodyDraft: String

    init(note: NoteItem, onBack: @escaping () -> Void) {
        self.note = note
        self.onBack = onBack
        _titleDraft = State(initialValue: note.customTitle ?? "")
        _bodyDraft = State(initialValue: note.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.callout)
                }
                .buttonStyle(.plain)

                TextField("Title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.headline)

                Spacer()

                Button { vm.delete(note); onBack() } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            TextEditor(text: $bodyDraft)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        }
        .onDisappear(perform: commit)
    }

    private func back() {
        commit()
        onBack()
    }

    private func commit() {
        vm.rename(note, to: titleDraft)
        vm.updateBody(note, to: bodyDraft)
    }
}
