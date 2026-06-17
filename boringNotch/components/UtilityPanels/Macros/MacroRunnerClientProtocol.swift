//
//  MacroRunnerClientProtocol.swift
//  boringNotch
//
//  Callback interface the APP vends to the helper so a running macro can stream
//  its output back. The helper holds the reverse side of the connection and
//  calls these as the process produces output and exits.
//
//  NOTE: this file is intentionally duplicated verbatim in the helper target
//  (BoringNotchXPCHelper/MacroRunnerClientProtocol.swift). The two copies MUST
//  stay byte-identical or the XPC interface selectors won't match.
//

import Foundation

@objc protocol MacroRunnerClientProtocol {
    func didReceiveOutput(runID: String, chunk: Data, isStderr: Bool)
    func didFinish(runID: String, exitCode: Int)
    func didFail(runID: String, message: String)
}
