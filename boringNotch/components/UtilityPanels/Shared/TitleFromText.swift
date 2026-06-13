//
//  TitleFromText.swift
//  boringNotch
//
//  First-line title derivation, extracted from ShelfItem.TextBlockData so Notes
//  (and future text panels) share one implementation.
//

import Foundation

extension String {
    /// The first non-empty line, trimmed and truncated to `maxLength` (with an
    /// ellipsis). Returns "Untitled" when there is no usable text.
    func titleFromFirstLine(maxLength: Int = 50) -> String {
        let firstLine = components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? ""

        if firstLine.isEmpty { return "Untitled" }
        if firstLine.count > maxLength {
            return String(firstLine.prefix(maxLength - 3)) + "..."
        }
        return firstLine
    }
}
