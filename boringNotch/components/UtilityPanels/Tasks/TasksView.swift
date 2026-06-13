//
//  TasksView.swift
//  boringNotch
//
//  Tasks panel: a plain local checklist — add, tick, delete, clear-done.
//

import SwiftUI

struct TasksView: View {
    @ObservedObject private var vm = TasksViewModel.shared
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tasks").font(.headline)
                if vm.openCount > 0 {
                    Text("\(vm.openCount)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.2)))
                }
                Spacer()
                if vm.hasCompleted {
                    Button { vm.clearCompleted() } label: {
                        Text("Clear done").font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }

            if vm.tasks.isEmpty {
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text("No tasks yet").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(vm.tasks) { task in
                            row(for: task)
                        }
                    }
                }
            }

            composer
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func row(for task: NotchTask) -> some View {
        HStack(spacing: 8) {
            Button { vm.toggle(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.callout)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? Color.secondary : Color.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { vm.delete(task) } label: {
                Image(systemName: "xmark").font(.caption2)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private var composer: some View {
        HStack(spacing: 6) {
            TextField("New task…", text: $draft)
                .textFieldStyle(.plain)
                .focused($composerFocused)
                .onSubmit(commit)
            Button(action: commit) {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }

    private func commit() {
        vm.add(title: draft)
        draft = ""
        composerFocused = false
    }
}
