import AppKit

enum ScreenshotPasteboardService {
    static func copyImage(at url: URL) {
        // Files inside the watched folder are reachable because the manager already holds
        // the security scope on the parent.
        guard let image = NSImage(contentsOf: url) else {
            NSLog("ScreenshotPasteboardService: failed to read image at \(url.path)")
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    static func copyFile(at url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
    }
}
