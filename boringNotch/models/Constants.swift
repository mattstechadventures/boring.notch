//
//  Constants.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 10. 17..
//

import SwiftUI
import Defaults

private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
let spacing: CGFloat = 16

struct CustomVisualizer: Codable, Hashable, Equatable, Defaults.Serializable {
    let UUID: UUID
    var name: String
    var url: URL
    var speed: CGFloat = 1.0
}

/// A user-configured focus-music track backed by a YouTube video.
/// We store the raw URL the user pastes and derive the video id / thumbnail / embed URL from it.
struct FocusTrack: Codable, Hashable, Equatable, Identifiable, Defaults.Serializable {
    var id: UUID = UUID()
    var label: String
    var youtubeURL: String
    /// Whether this track is shown in the in-notch list. Disabled tracks remain in Settings.
    var isEnabled: Bool = true

    init(id: UUID = UUID(), label: String, youtubeURL: String, isEnabled: Bool = true) {
        self.id = id
        self.label = label
        self.youtubeURL = youtubeURL
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey { case id, label, youtubeURL, isEnabled }

    // Custom decode so adding `isEnabled` doesn't fail to decode tracks saved before it
    // existed (a throw would wipe the whole persisted array).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decode(String.self, forKey: .label)
        youtubeURL = try c.decode(String.self, forKey: .youtubeURL)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    /// Parses the YouTube video id from the common URL shapes:
    /// `watch?v=ID`, `youtu.be/ID`, `/embed/ID`, `/shorts/ID`, `/live/ID`.
    /// Only returns an id when the host is a genuine YouTube host and the id
    /// matches YouTube's 11-character `[A-Za-z0-9_-]` format.
    var videoID: String? {
        guard let components = URLComponents(string: youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased(),
              isYouTubeHost(host) else {
            return nil
        }

        // watch?v=ID
        if let v = components.queryItems?.first(where: { $0.name == "v" })?.value, isValidID(v) {
            return v
        }

        // Path-based forms.
        let pathSegments = components.path.split(separator: "/").map(String.init)
        if host == "youtu.be" || host.hasSuffix(".youtu.be"), let first = pathSegments.first, isValidID(first) {
            return first
        }
        if let idx = pathSegments.firstIndex(where: { ["embed", "shorts", "live", "v"].contains($0) }),
           idx + 1 < pathSegments.count, isValidID(pathSegments[idx + 1]) {
            return pathSegments[idx + 1]
        }

        return nil
    }

    private func isYouTubeHost(_ host: String) -> Bool {
        host == "youtube.com" || host.hasSuffix(".youtube.com")
            || host == "youtu.be" || host.hasSuffix(".youtu.be")
    }

    private func isValidID(_ id: String) -> Bool {
        id.count == 11 && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    /// hqdefault is always present for valid videos (unlike maxresdefault).
    var thumbnailURL: URL? {
        guard let id = videoID else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
    }

    /// Embed URL with the IFrame JS API enabled so we can drive play/pause programmatically.
    var embedURL: URL? {
        guard let id = videoID else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&enablejsapi=1&playsinline=1")
    }

    var isValid: Bool { videoID != nil }
}

enum CalendarSelectionState: Codable, Defaults.Serializable {
    case all
    case selected(Set<String>)
}

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

// Define notification names at file scope
extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
}

// Media controller types for selection in settings
enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    
    var id: String { self.rawValue }
}

// Sneak peek styles for selection in settings
enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"
    
    var id: String { self.rawValue }
}

// Action to perform when Option (⌥) is held while pressing media keys
enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"

    var id: String { self.rawValue }
}

extension Defaults.Keys {
    // MARK: General
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)
    static let automaticallySwitchDisplay = Key<Bool>("automaticallySwitchDisplay", default: true)
    static let releaseName = Key<String>("releaseName", default: "Flying Rabbit 🐇🪽")
    
    // MARK: Behavior
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.3)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let extendHoverArea = Key<Bool>("extendHoverArea", default: false)
    static let notchHeightMode = Key<WindowHeightMode>(
        "notchHeightMode",
        default: WindowHeightMode.matchRealNotchSize
    )
    static let nonNotchHeightMode = Key<WindowHeightMode>(
        "nonNotchHeightMode",
        default: WindowHeightMode.matchMenuBar
    )
    static let nonNotchHeight = Key<CGFloat>("nonNotchHeight", default: 32)
    static let notchHeight = Key<CGFloat>("notchHeight", default: 32)
    //static let openLastTabByDefault = Key<Bool>("openLastTabByDefault", default: false)
    static let showOnLockScreen = Key<Bool>("showOnLockScreen", default: false)
    static let hideFromScreenRecording = Key<Bool>("hideFromScreenRecording", default: false)
    
    // MARK: Appearance
    static let showEmojis = Key<Bool>("showEmojis", default: false)
    //static let alwaysShowTabs = Key<Bool>("alwaysShowTabs", default: true)
    static let showMirror = Key<Bool>("showMirror", default: false)
    static let mirrorShape = Key<MirrorShapeEnum>("mirrorShape", default: MirrorShapeEnum.rectangle)
    static let settingsIconInNotch = Key<Bool>("settingsIconInNotch", default: true)
    static let lightingEffect = Key<Bool>("lightingEffect", default: true)
    static let enableShadow = Key<Bool>("enableShadow", default: true)
    static let cornerRadiusScaling = Key<Bool>("cornerRadiusScaling", default: true)

    static let showNotHumanFace = Key<Bool>("showNotHumanFace", default: false)
    static let tileShowLabels = Key<Bool>("tileShowLabels", default: false)
    static let showCalendar = Key<Bool>("showCalendar", default: false)
    static let hideCompletedReminders = Key<Bool>("hideCompletedReminders", default: true)
    static let sliderColor = Key<SliderColorEnum>(
        "sliderUseAlbumArtColor",
        default: SliderColorEnum.white
    )
    static let playerColorTinting = Key<Bool>("playerColorTinting", default: true)
    static let useMusicVisualizer = Key<Bool>("useMusicVisualizer", default: true)
    static let customVisualizers = Key<[CustomVisualizer]>("customVisualizers", default: [])
    static let selectedVisualizer = Key<CustomVisualizer?>("selectedVisualizer", default: nil)
    
    // MARK: Gestures
    static let enableGestures = Key<Bool>("enableGestures", default: true)
    static let closeGestureEnabled = Key<Bool>("closeGestureEnabled", default: true)
    static let gestureSensitivity = Key<CGFloat>("gestureSensitivity", default: 200.0)
    
    // MARK: Media playback
    static let coloredSpectrogram = Key<Bool>("coloredSpectrogram", default: true)
    static let enableSneakPeek = Key<Bool>("enableSneakPeek", default: false)
    static let sneakPeekStyles = Key<SneakPeekStyle>("sneakPeekStyles", default: .standard)
    static let waitInterval = Key<Double>("waitInterval", default: 3)
    static let showShuffleAndRepeat = Key<Bool>("showShuffleAndRepeat", default: false)
    static let enableLyrics = Key<Bool>("enableLyrics", default: false)
    static let musicControlSlots = Key<[MusicControlButton]>(
        "musicControlSlots",
        default: MusicControlButton.defaultLayout
    )
    static let musicControlSlotLimit = Key<Int>(
        "musicControlSlotLimit",
        default: MusicControlButton.defaultLayout.count
    )
    
    // MARK: Battery
    static let showPowerStatusNotifications = Key<Bool>("showPowerStatusNotifications", default: true)
    static let showBatteryIndicator = Key<Bool>("showBatteryIndicator", default: true)
    static let showBatteryPercentage = Key<Bool>("showBatteryPercentage", default: true)
    static let showPowerStatusIcons = Key<Bool>("showPowerStatusIcons", default: true)
    
    // MARK: Downloads
    static let enableDownloadListener = Key<Bool>("enableDownloadListener", default: true)
    static let enableSafariDownloads = Key<Bool>("enableSafariDownloads", default: true)
    static let selectedDownloadIndicatorStyle = Key<DownloadIndicatorStyle>("selectedDownloadIndicatorStyle", default: DownloadIndicatorStyle.progress)
    static let selectedDownloadIconStyle = Key<DownloadIconStyle>("selectedDownloadIconStyle", default: DownloadIconStyle.onlyAppIcon)
    
    // MARK: HUD
    static let hudReplacement = Key<Bool>("hudReplacement", default: false)
    static let inlineHUD = Key<Bool>("inlineHUD", default: false)
    static let enableGradient = Key<Bool>("enableGradient", default: false)
    static let systemEventIndicatorShadow = Key<Bool>("systemEventIndicatorShadow", default: false)
    static let systemEventIndicatorUseAccent = Key<Bool>("systemEventIndicatorUseAccent", default: false)
    static let showOpenNotchHUD = Key<Bool>("showOpenNotchHUD", default: true)
    static let showOpenNotchHUDPercentage = Key<Bool>("showOpenNotchHUDPercentage", default: true)
    static let showClosedNotchHUDPercentage = Key<Bool>("showClosedNotchHUDPercentage", default: false)
    // Option key modifier behaviour for media keys
    static let optionKeyAction = Key<OptionKeyAction>("optionKeyAction", default: OptionKeyAction.openSettings)
    
    // MARK: Shelf
    static let boringShelf = Key<Bool>("boringShelf", default: true)
    static let openShelfByDefault = Key<Bool>("openShelfByDefault", default: true)
    static let shelfTapToOpen = Key<Bool>("shelfTapToOpen", default: true)
    static let quickShareProvider = Key<String>("quickShareProvider", default: QuickShareProvider.defaultProvider.id)
    static let copyOnDrag = Key<Bool>("copyOnDrag", default: false)
    static let autoRemoveShelfItems = Key<Bool>("autoRemoveShelfItems", default: false)
    static let expandedDragDetection = Key<Bool>("expandedDragDetection", default: true)
    
    // MARK: Calendar
    static let calendarSelectionState = Key<CalendarSelectionState>("calendarSelectionState", default: .all)
    static let hideAllDayEvents = Key<Bool>("hideAllDayEvents", default: false)
    static let showFullEventTitles = Key<Bool>("showFullEventTitles", default: false)
    static let autoScrollToNextEvent = Key<Bool>("autoScrollToNextEvent", default: true)
    
    // MARK: Fullscreen Media Detection
    static let hideNotchOption = Key<HideNotchOption>("hideNotchOption", default: .nowPlayingOnly)
    
    // MARK: Media Controller
    static let mediaController = Key<MediaControllerType>("mediaController", default: defaultMediaController)

    // MARK: Claude Code
    static let enableClaudeCode = Key<Bool>("enableClaudeCode", default: true)
    static let enableClaudeCodeCollapsedView = Key<Bool>("enableClaudeCodeCollapsedView", default: true)
    /// Minutes of JSONL inactivity below which a session is "active" (green dot)
    static let claudeActiveThresholdMinutes = Key<Double>("claudeActiveThresholdMinutes", default: 5)
    /// Minutes below which a session is "recent" (amber dot). Above this = "idle" (red dot).
    static let claudeRecentThresholdMinutes = Key<Double>("claudeRecentThresholdMinutes", default: 60)
    static let showActiveClaudeSessions = Key<Bool>("showActiveClaudeSessions", default: true)
    static let showRecentClaudeSessions = Key<Bool>("showRecentClaudeSessions", default: true)
    static let showIdleClaudeSessions = Key<Bool>("showIdleClaudeSessions", default: true)
    static let claudeSessionGrouping = Key<SessionGrouping>("claudeSessionGrouping", default: .byProcess)

    // MARK: Advanced Settings
    static let useCustomAccentColor = Key<Bool>("useCustomAccentColor", default: false)
    static let customAccentColorData = Key<Data?>("customAccentColorData", default: nil)
    // Show or hide the title bar
    static let hideTitleBar = Key<Bool>("hideTitleBar", default: true)
    
    // Helper to determine the default media controller based on NowPlaying deprecation status
    static var defaultMediaController: MediaControllerType {
        if MusicManager.shared.isNowPlayingDeprecated {
            return .appleMusic
        } else {
            return .nowPlaying
        }
    }

    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCache_v1", default: false)

    // MARK: Screenshots
    static let screenshotTrayEnabled = Key<Bool>("screenshotTrayEnabled", default: false)
    static let screenshotsFolderBookmark = Key<Data?>("screenshotsFolderBookmark", default: nil)
    static let screenshotPinnedFolders = Key<[PinnedFolder]>("screenshotPinnedFolders", default: [])
    static let screenshotTrayMaxVisible = Key<Int>("screenshotTrayMaxVisible", default: 12)
    static let screenshotCaptureAnimationEnabled = Key<Bool>("screenshotCaptureAnimationEnabled", default: true)

    // MARK: Pomodoro
    static let enablePomodoro = Key<Bool>("enablePomodoro", default: true)
    static let pomodoroFocusMinutes = Key<Double>("pomodoroFocusMinutes", default: 25)
    static let pomodoroBreakMinutes = Key<Double>("pomodoroBreakMinutes", default: 5)
    static let pomodoroLongBreakMinutes = Key<Double>("pomodoroLongBreakMinutes", default: 15)
    static let pomodoroSessionsBeforeLongBreak = Key<Int>("pomodoroSessionsBeforeLongBreak", default: 4)
    static let pomodoroAutoStartNext = Key<Bool>("pomodoroAutoStartNext", default: true)
    static let showPomodoroInClosedNotch = Key<Bool>("showPomodoroInClosedNotch", default: true)

    // MARK: Focus Music
    static let enableFocusMusic = Key<Bool>("enableFocusMusic", default: true)
    static let focusTracks = Key<[FocusTrack]>("focusTracks", default: [])
    static let focusMusicPauseOtherMedia = Key<Bool>("focusMusicPauseOtherMedia", default: false)
    static let focusMusicAutoOpenTab = Key<Bool>("focusMusicAutoOpenTab", default: true)

    // MARK: Utility Panels
    static let enableNotes = Key<Bool>("enableNotes", default: true)
    static let enableTasks = Key<Bool>("enableTasks", default: true)
    static let enableClipboard = Key<Bool>("enableClipboard", default: true)
    static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 50)
    static let enableFiles = Key<Bool>("enableFiles", default: true)
    static let filesPinnedFolders = Key<[PinnedFolder]>("filesPinnedFolders", default: [])
    static let enableMacros = Key<Bool>("enableMacros", default: true)

    // MARK: Notch Header Layout
    // Ordered slot arrangement per side (left-to-right = priority for capacity
    // clamping). This is the user's *intent*; rendering clamps to live geometry.
    // New utility panels are appended last so they clamp out first on narrow
    // displays — existing items are never pushed off.
    static let headerLeftOrder = Key<[PanelID]>("headerLeftOrder", default: [.home, .shelf, .screenshots, .claudeCode, .notes, .tasks])
    static let headerRightOrder = Key<[PanelID]>("headerRightOrder", default: [.pomodoro, .focusMusic, .webcam, .settings, .battery, .clipboard, .files])
    // Per-side cap on visible slots (0 = use full geometric capacity).
    static let headerLeftMax = Key<Int>("headerLeftMax", default: 0)
    static let headerRightMax = Key<Int>("headerRightMax", default: 0)
    // Elastic inter-icon padding per side.
    static let headerLeftElastic = Key<Bool>("headerLeftElastic", default: true)
    static let headerRightElastic = Key<Bool>("headerRightElastic", default: true)

    // MARK: Default View
    // What the notch shows when it opens. `.smart` reproduces today's behaviour
    // (Focus Music when playing, else Shelf when it has items, else fallback).
    static let defaultViewPolicy = Key<DefaultViewPolicy>("defaultViewPolicy", default: .smart)
    static let defaultViewFallback = Key<PanelID>("defaultViewFallback", default: .home)
    static let lastView = Key<PanelID>("lastView", default: .home)
}
