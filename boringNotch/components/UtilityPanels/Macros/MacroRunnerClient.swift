//
//  MacroRunnerClient.swift
//  boringNotch
//
//  App-side receiver for the helper's macro-run callbacks. Decodes streamed
//  bytes and forwards everything to MacrosViewModel on the main actor.
//

import Foundation

final class MacroRunnerClient: NSObject, MacroRunnerClientProtocol {

    func didReceiveOutput(runID: String, chunk: Data, isStderr: Bool) {
        // Forward raw bytes; the view model decodes incrementally so a multibyte
        // character split across chunk boundaries isn't corrupted.
        Task { @MainActor in
            MacrosViewModel.shared.appendOutput(runID: runID, data: chunk, isStderr: isStderr)
        }
    }

    func didFinish(runID: String, exitCode: Int) {
        Task { @MainActor in
            MacrosViewModel.shared.finish(runID: runID, exitCode: exitCode)
        }
    }

    func didFail(runID: String, message: String) {
        Task { @MainActor in
            MacrosViewModel.shared.fail(runID: runID, message: message)
        }
    }
}
