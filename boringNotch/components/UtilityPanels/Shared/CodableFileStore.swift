//
//  CodableFileStore.swift
//  boringNotch
//
//  Generic JSON-array store at
//  ~/Library/Application Support/boringNotch/<subdirectory>/<filename>.
//  Generalizes ShelfPersistenceService: atomic writes, iso8601 dates, and
//  best-effort per-item recovery so one corrupt element doesn't wipe the file.
//

import Foundation

final class CodableFileStore<Element: Codable> {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(subdirectory: String, filename: String) {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true)
        let dir = (support ?? fm.temporaryDirectory)
            .appendingPathComponent("boringNotch", isDirectory: true)
            .appendingPathComponent(subdirectory, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [Element] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }

        // Fast path: decode the whole array.
        if let items = try? decoder.decode([Element].self, from: data) { return items }

        // Recovery: decode item-by-item, discarding only the corrupt ones.
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        var valid: [Element] = []
        for json in jsonArray {
            if let itemData = try? JSONSerialization.data(withJSONObject: json),
               let item = try? decoder.decode(Element.self, from: itemData) {
                valid.append(item)
            }
        }
        return valid
    }

    func save(_ items: [Element]) {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
