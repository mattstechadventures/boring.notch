//
//  FocusMusicManager.swift
//  boringNotch
//
//  Plays a YouTube-backed focus track inside the app via a hidden WKWebView driven
//  by the YouTube IFrame Player API. Audio keeps playing without a browser tab and
//  survives the notch closing. Playback state is reported back from the real player
//  (not assumed), so the UI stays in sync.
//

import Combine
import Defaults
import SwiftUI
import WebKit

@MainActor
final class FocusMusicManager: NSObject, ObservableObject {
    static let shared = FocusMusicManager()

    @Published private(set) var currentTrack: FocusTrack?
    @Published private(set) var isPlaying: Bool = false
    /// Set when an embed refuses to load / play so the UI can surface it.
    @Published private(set) var loadFailed: Bool = false

    /// Hidden web view, retained for the lifetime of the (singleton) manager so audio
    /// is never interrupted by deallocation.
    private var webView: WKWebView?
    /// Offscreen host window. A fully detached WKWebView can have its web content process
    /// throttled/suspended; keeping it in a window keeps media playback reliable.
    private var hostWindow: NSWindow?

    private static let messageName = "focusMusic"
    /// The YouTube IFrame API refuses to run from a null/opaque origin (which is what
    /// `loadHTMLString` produces). We load the player via `loadSimulatedRequest` so the
    /// document gets a real HTTPS origin, and set the player's `origin` to match. Using a
    /// known-good real origin avoids the "embedding disabled" rejection.
    private static let embedOrigin = "https://www.mattstechadventures.com.au"

    private override init() {
        super.init()
    }

    // MARK: - Public controls

    func play(_ track: FocusTrack) {
        guard let videoID = track.videoID else {
            loadFailed = true
            return
        }

        // Optionally pause other media (Spotify/Apple Music) before we start.
        if Defaults[.focusMusicPauseOtherMedia] && MusicManager.shared.isPlaying {
            MusicManager.shared.pause()
        }

        loadFailed = false
        currentTrack = track

        let web = ensureWebView()
        // Load the HTML as if served from a real HTTPS origin so the IFrame API runs.
        var request = URLRequest(url: URL(string: Self.embedOrigin + "/")!)
        request.setValue(Self.embedOrigin, forHTTPHeaderField: "Referer")
        web.loadSimulatedRequest(request, responseHTML: playerHTML(videoID: videoID))
        // Optimistic; corrected by onStateChange messages from the real player.
        isPlaying = true
    }

    func togglePlayPause() {
        guard currentTrack != nil, let web = webView else { return }
        let js = isPlaying ? "window.bnPause && window.bnPause();" : "window.bnPlay && window.bnPlay();"
        web.evaluateJavaScript(js, completionHandler: nil)
    }

    func stop() {
        webView?.evaluateJavaScript("window.bnStop && window.bnStop();", completionHandler: nil)
        webView?.loadHTMLString("", baseURL: nil)
        isPlaying = false
        currentTrack = nil
    }

    func isCurrent(_ track: FocusTrack) -> Bool {
        currentTrack?.id == track.id
    }

    /// Fallback for videos whose owner has disabled embedding: open on YouTube directly.
    func openCurrentOnYouTube() {
        guard let track = currentTrack, let url = URL(string: track.youtubeURL) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Web view

    private func ensureWebView() -> WKWebView {
        if let web = webView { return web }

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.userContentController.add(self, name: Self.messageName)

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        webView = web

        // Park the webview in a tiny, invisible, offscreen window so its content
        // process is not suspended while it plays in the background.
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = web
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.level = .init(Int(CGWindowLevelForKey(.desktopWindow)))
        window.orderBack(nil)
        hostWindow = window

        return web
    }

    /// HTML wrapper that hosts a YT.Player and exposes bnPlay/bnPause/bnStop plus
    /// state callbacks back into Swift.
    ///
    /// Mirrors the working web pattern (~/dev/personal/profile2 useYouTubePlayer):
    /// the player is created on a blank div with NO videoId in the constructor, then
    /// `loadVideoById` is called in onReady. This plays many videos that the direct
    /// `/embed/VIDEOID` URL refuses, and reports real playback state back to Swift.
    private func playerHTML(videoID: String) -> String {
        """
        <!DOCTYPE html><html><head><meta name="viewport" content="initial-scale=1.0"/>
        <style>html,body{margin:0;background:#000;}</style></head>
        <body>
        <div id="player"></div>
        <script>
          var player;
          var vid = '\(videoID)';
          function post(state){ try{ window.webkit.messageHandlers.\(Self.messageName).postMessage(state); }catch(e){} }
          window.bnPlay = function(){ try{ if(player&&player.playVideo) player.playVideo(); }catch(e){} };
          window.bnPause = function(){ try{ if(player&&player.pauseVideo) player.pauseVideo(); }catch(e){} };
          window.bnStop = function(){ try{ if(player&&player.stopVideo) player.stopVideo(); }catch(e){} };
          var tag = document.createElement('script');
          tag.src = "https://www.youtube.com/iframe_api";
          document.body.appendChild(tag);
          function onYouTubeIframeAPIReady(){
            player = new YT.Player('player', {
              height:'1', width:'1',
              playerVars:{autoplay:0, playsinline:1, controls:0, disablekb:1, fs:0, modestbranding:1, rel:0, origin:'\(Self.embedOrigin)'},
              events:{
                'onReady': function(e){
                  // Loading by id (rather than constructor videoId) is the permissive path.
                  e.target.loadVideoById(vid);
                  e.target.playVideo();
                },
                'onStateChange': function(e){
                  // 1 = playing, 2 = paused, 0 = ended
                  if(e.data===1) post('playing');
                  else if(e.data===2) post('paused');
                  else if(e.data===0) post('ended');
                },
                // 101/150 = embedding disabled by owner; 100 = not found; 2/5 = bad param / html5
                'onError': function(e){ post('error:'+e.data); }
              }
            });
          }
        </script>
        </body></html>
        """
    }
}

extension FocusMusicManager: WKScriptMessageHandler {
    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let state = message.body as? String else { return }
        Task { @MainActor in
            switch state {
            case "playing":
                self.isPlaying = true
                self.loadFailed = false
            case "paused", "ended":
                self.isPlaying = false
            case let s where s.hasPrefix("error"):
                self.loadFailed = true
                self.isPlaying = false
            default:
                break
            }
        }
    }
}

extension FocusMusicManager: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loadFailed = true }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.loadFailed = true }
    }
}
