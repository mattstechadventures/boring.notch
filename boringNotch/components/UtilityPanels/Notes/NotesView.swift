//
//  NotesView.swift
//  boringNotch
//
//  Notes panel: list of notes with a "new note" composer, and an inline detail
//  view (editable title + body) when a row is opened.
//

import SwiftUI

struct NotesView: View {
    @ObservedObject private var vm = NotesViewModel.shared
    @State private var draft = ""
    @State private var openNote: NoteItem?
    @FocusState private var composerFocused: Bool

    var body: some View {
        Group {
            if let note = openNote {
                NoteDetailView(note: note) { openNote = nil }
            } else {
                listView
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var listView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Notes").font(.headline)
                if !vm.notes.isEmpty {
                    Text("\(vm.notes.count)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                }
                Spacer()
                if !vm.notes.isEmpty {
                    Button { vm.deleteAll() } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Delete all notes")
                }
            }

            if vm.notes.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("No notes yet").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(vm.notes) { note in
                            row(for: note)
                        }
                    }
                }
            }

            composer
        }
    }

    private func row(for note: NoteItem) -> some View {
        Button { openNote = note } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 18)
                Text(note.title)
                    .font(.callout).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.secondary)
                Button { vm.delete(note) } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var composer: some View {
        HStack(spacing: 6) {
            TextField("New note…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .focused($composerFocused)
                .onSubmit(commit)
            Button(action: commit) {
                Image(systemName: "arrow.up.circle.fill").font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func commit() {
        vm.add(text: draft)
        draft = ""
        composerFocused = false
    }
}
