//
//  TasksViewModel.swift
//  boringNotch
//
//  @MainActor singleton over a CodableFileStore<NotchTask>. Persists on every
//  mutation. New tasks appended at the end.
//

import SwiftUI

@MainActor
final class TasksViewModel: ObservableObject {
    static let shared = TasksViewModel()

    @Published private(set) var tasks: [NotchTask] = []

    private let store = CodableFileStore<NotchTask>(subdirectory: "Tasks", filename: "tasks.json")

    private init() {
        tasks = store.load()
    }

    var openCount: Int { tasks.filter { !$0.isDone }.count }
    var hasCompleted: Bool { tasks.contains { $0.isDone } }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(NotchTask(title: trimmed))
        persist()
    }

    func toggle(_ task: NotchTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone.toggle()
        persist()
    }

    func delete(_ task: NotchTask) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    func clearCompleted() {
        tasks.removeAll { $0.isDone }
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        store.save(tasks)
    }
}
