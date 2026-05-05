# Screenshot Tray — Implementation Plan

Status: planning approved 2026-05-04. Decisions locked: see [Decisions](#decisions). Implementation pending.

## Goal

A "Screenshot Tray" feature added as a new tab in the dynamic notch UI. The user captures screenshots normally (⌘⇧3 / ⌘⇧4 / ⌘⇧5), they land in a dedicated folder that the app monitors, and the notch surfaces them for fast routing/copying.

## Design

### Tray layout

- **New 📸 tab** in the notch top bar, alongside existing 🏠 home and 📥 shelf/airdrop tabs. The shelf tab is untouched.
- **Horizontal thumbnail strip** (left/main area) — most recent first, no filenames, tiny relative-time label under each thumb (`1m`, `3h`, `yest.`).
- **Compact 2×4 pinned-folder grid** (right) — ~32–40px folder icons, name on hover and during drag-over. `＋` cell to add a pin. Overflow ("▸ more") when >8 pins.
- **"Open screenshots folder" affordance** — hidden by default. Appears when the strip background is **clicked**. Hides as soon as a drag begins.
- **"+ show more"** at end of strip when more screenshots exist than fit. Expands the visible cap **in-place** (longer horizontal scroll), not a modal.
- **Empty state** — literally empty (no helper text or illustration).

### Per-thumb interactions

- **Hover**: surfaces quick action overlay (copy image, copy file, reveal in Finder, ⋯).
- **Right-click**: full context menu — Copy image / Copy file / Reveal in Finder / Quick Look (space) / Delete.
- **Drag**: produces an `NSItemProvider` carrying the file URL — works system-wide (Finder, Slack, Photos, etc.), not just within the app.

### Drop targets — pinned folders

- **macOS Finder convention**: no modifier = move, Option held = copy.
- On successful **move**: thumb disappears from tray; toast bar shows "✓ Moved to <Folder> · undo" for ~5s.
- On **copy**: thumb stays. No toast (no undo needed for copies).

### Copy actions for paste targets

- **Copy image** → puts image bitmap (PNG/TIFF) on `NSPasteboard` so it pastes as image (e.g. into Claude Desktop chat, image fields).
- **Copy file** → puts file URL on `NSPasteboard` so it pastes as a file reference (e.g. attaches in Slack).

Both are needed; different paste targets accept different things.

### Capture animation

When a new file lands in the watched folder, the notch "breathes out" ~40% taller for ~0.5s — single thumb slides in from a virtual camera with "saved ✓" affirmation, then collapses. Reuses the existing live-activity expand/collapse machinery used for music HUD, charging, etc.

### Persistence

- Pinned folders → `UserDefaults` via existing `Defaults.Serializable` pattern.
- Watched folder → security-scoped bookmark (sandbox requirement).
- Tray = **queue, not library**. When moved out, items leave. "Show more" reveals older items in the same folder. The watched folder is the source of truth.

## Decisions

| # | Decision | Choice |
|---|----------|--------|
| 1 | How to apply macOS screenshot save location | **Out of scope.** User configures macOS via ⌘⇧5 → Options → Save to, pointing it at the same folder our app watches. We don't try to programmatically override the system default. |
| 2 | First-run flow | **Lazy** — prompt on first click of the camera tab, not during onboarding. Less intrusive, opt-in. |
| 3 | Pre-seed pinned folders | **Empty** — pins should be intentional. |
| 4 | "Show more" UX | **In-place expansion** — keep allowing the strip to scroll right; no modal. |
| — | Drag modifier convention | macOS Finder default — no modifier = move, Option = copy. |
| — | Tab placement | New 📸 tab; existing 📥 (airdrop/shelf) untouched. |
| — | Empty state | Literally empty. |
| — | Capture animation | Reuse live-activity breathe; ~0.5s; ~40% chin expansion. |

## Codebase survey (findings)

### Tab system
- Enum `NotchViews` at `boringNotch/enums/generic.swift:27` (currently `.home`, `.shelf`).
- Tab definitions: `tabs` array at `boringNotch/components/Tabs/TabSelectionView.swift:17`, `TabModel` struct at line 10. Tab buttons drive `coordinator.currentView`.
- Active-view switch: `boringNotch/ContentView.swift:347-353`.
- Tab visibility logic: `BoringViewCoordinator.alwaysShowTabs` and `openLastTabByDefault` at `boringNotch/BoringViewCoordinator.swift:64-81`.
- Header rendering: `boringNotch/components/Notch/BoringHeader.swift:18-23`.

### Live-activity expand/collapse (the "breathe")
- Trigger: `BoringViewCoordinator.toggleExpandingView(status:type:value:browser:)` at `BoringViewCoordinator.swift:262`. `expandingView` (`ExpandedItem`) auto-clears after 2–3s.
- Visual: `ContentView.NotchLayout()` at `ContentView.swift:260-298` — when `coordinator.expandingView.type == .battery && coordinator.expandingView.show && vm.notchState == .closed`, the chin widens (see `computedChinWidth` at lines 61-81).
- Reference call site: `BatteryStatusViewModel.swift:124-128` — `coordinator.toggleExpandingView(status: true, type: .battery)`.
- `LiveActivityModifier` at `boringNotch/components/Live activities/LiveActivityModifier.swift` — generic overlay helper.
- `SneakContentType` at `BoringViewCoordinator.swift:13` — we add a `.screenshot` case.

### Managers / services
- Long-lived singletons live in `boringNotch/managers/` (`MusicManager`, `BatteryActivityManager`, `WebcamManager`, `BrightnessManager`, `VolumeManager`, `CalendarManager`, `ImageService`, `NotchSpaceManager`).
- Observers (event-driven) live in `boringNotch/observers/` (`DragDetector`, `MediaKeyInterceptor`, `FullscreenMediaDetection`).
- `ScreenshotManager` (folder watcher + ordered list + thumbnails) → `boringNotch/managers/`.
- Folder watcher (FSEvents) → `boringNotch/observers/ScreenshotFolderWatcher.swift`.

### Settings UI
- Entry: `boringNotch/components/Settings/SettingsView.swift` — sidebar with `NavigationLink(value: "...")`. Add a new `"Screenshots"` link.
- Defaults are added to `Defaults.Keys` at `boringNotch/models/Constants.swift:71-201` (see existing `MARK: Shelf` block at line 165).

### Drag-drop in SwiftUI
- The codebase mixes `.onDrop` (SwiftUI, see `ContentView.swift:364, 495` and `ShelfView.swift:24, 106`) for incoming drops, and a custom `NSViewRepresentable` `DraggableClickView` for outgoing drags — see `ShelfItemView.swift:172-371`. We mirror the AppKit pattern for screenshot thumbnails.
- `DragPreviewView` at `boringNotch/components/Shelf/Views/DragPreviewView.swift` — pattern to reuse.

### Localization
- `Localizable.xcstrings` at `boringNotch/Localizable.xcstrings`. Build flag `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` and `SWIFT_EMIT_LOC_STRINGS = YES`. Convention: just use `Text("…")` / `String(localized: "…")`; Xcode auto-extracts on build. No manual catalog edits for English.

### macOS deployment target
- `MACOSX_DEPLOYMENT_TARGET = 14.0` (Sonoma). All needed APIs available: `.draggable`, `.dropDestination`, `Transferable`, `QLThumbnailGenerator`, `FSEventStream`, `NSItemProvider` URL types.

### Sandbox / entitlements
- App sandbox is on (`com.apple.security.app-sandbox = true` at `boringNotch/boringNotch.entitlements:5`).
- Already entitled: `files.user-selected.read-write`, `files.bookmarks.app-scope`, `files.bookmarks.document-scope`, `automation.apple-events` (with temp-exception for spotify/music), `network.client/server`, `device.camera`.
- Consequence: sandboxed app can't auto-read `~/Pictures/Notchdock Screenshots`. Needs a security-scoped bookmark obtained via `NSOpenPanel`.
- The `Bookmark` abstraction at `boringNotch/components/Shelf/Models/Bookmark.swift` already does security-scoped bookmarks. Reuse this pattern.

## Files

> **Project structure note.** All new files live under a single feature folder `boringNotch/components/Screenshots/`, registered as a `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synchronized group) — same pattern as the existing `private/` folder. Result: future files added inside `Screenshots/` are auto-tracked by Xcode without pbxproj edits, and the entire feature is contained in one directory for clean upstream-merge story.

### New files

| Path | Purpose |
|---|---|
| `boringNotch/components/Screenshots/Manager/ScreenshotManager.swift` | Singleton: holds ordered `[Screenshot]`, owns the folder watcher, posts capture events, exposes move/copy/undo, manages the security-scoped bookmark. |
| `boringNotch/components/Screenshots/Watcher/ScreenshotFolderWatcher.swift` | `FSEventStreamCreate` watcher; emits add/remove/rename callbacks on the main actor. |
| `boringNotch/components/Screenshots/Models/Screenshot.swift` | `Screenshot` value: `id (UUID)`, `url (URL)`, `addedAt (Date)`, `byteSize (Int64)`. |
| `boringNotch/components/Screenshots/Models/PinnedFolder.swift` | Codable: `id`, `displayName`, `bookmark: Data`. |
| `boringNotch/components/Screenshots/ViewModels/ScreenshotTrayViewModel.swift` | `@MainActor` view model: visible window of items, "show more" expansion, pinned folder list, undo stack, toast state. |
| `boringNotch/components/Screenshots/Services/ScreenshotPasteboardService.swift` | "Copy image" (PNG/TIFF) and "Copy file" (URL) helpers. |
| `boringNotch/components/Screenshots/Services/ScreenshotMoveService.swift` | Performs move (default) or copy (Option) into a pinned folder via security-scoped access; returns `UndoOp` for the toast. |
| `boringNotch/components/Screenshots/Services/PinnedFoldersStore.swift` | Persists `[PinnedFolder]` via `Defaults`. |
| `boringNotch/components/Screenshots/Views/ScreenshotTrayView.swift` | Tab body: thumb strip + pin grid + tap-to-show "open folder" + "+ show more". |
| `boringNotch/components/Screenshots/Views/ScreenshotThumbView.swift` | One thumb: image, relative-time, hover quick-actions, right-click menu, draggable. |
| `boringNotch/components/Screenshots/Views/PinnedFolderCellView.swift` | One pin cell: 32–40px folder icon, hover-revealed name, drop target. |
| `boringNotch/components/Screenshots/Views/ScreenshotLiveActivity.swift` | The "breathe" view shown in the chin when `expandingView.type == .screenshot`. |
| `boringNotch/components/Screenshots/Views/ScreenshotToastView.swift` | "Moved to <Folder> · Undo" pill rendered as overlay inside the tray. |
| `boringNotch/components/Settings/ScreenshotSettings.swift` | Settings page: pick watched folder, manage pinned folders, hint about pointing macOS save location (⌘⇧5 → Options → Save to). |

### Modified files

| Path | Why |
|---|---|
| `boringNotch/enums/generic.swift` | Add `case screenshots` to `NotchViews`. |
| `boringNotch/BoringViewCoordinator.swift` | Add `case screenshot` to `SneakContentType`. Override the auto-clear timer for `.screenshot` to 0.5s. |
| `boringNotch/components/Tabs/TabSelectionView.swift` | Append `TabModel(label: "Screenshots", icon: "camera.fill", view: .screenshots)` to `tabs`. |
| `boringNotch/ContentView.swift` | Add `case .screenshots: ScreenshotTrayView()` to switch (line 347). Extend `expandingView.type == .battery` chin/branch (lines 260, 290) to also handle `.screenshot` → `ScreenshotLiveActivity()`. Extend `computedChinWidth` (line 61) for `.screenshot`. |
| `boringNotch/components/Notch/BoringHeader.swift` | Update tab visibility gate at line 19 to also force tabs visible when there are screenshots. |
| `boringNotch/models/Constants.swift` | Add `Defaults.Keys`: `screenshotTrayEnabled`, `screenshotsFolderBookmark`, `screenshotPinnedFolders`, `screenshotTrayMaxVisible` (default 12), `screenshotCaptureAnimationEnabled` (default true). |
| `boringNotch/components/Settings/SettingsView.swift` | Add `NavigationLink(value: "Screenshots")` to sidebar; add `case "Screenshots": ScreenshotSettings()` to detail switch. |
| `boringNotch/boringNotchApp.swift` | Start `ScreenshotManager.shared.start()` after window setup; stop on `applicationWillTerminate`. |

## Steps

Each step ends in a buildable, working state.

1. **Watched-folder plumbing (no UI).** `Defaults.Keys` + `Screenshot` model + stub `ScreenshotManager.shared` with empty published `items`.
2. **Folder watcher (no UI).** `ScreenshotFolderWatcher` (FSEventStream, 100ms coalesce). Filters: skip dot-files, in-flight `.TMP`, non-image extensions. Stability check (size unchanged 2 ticks).
3. **Capture-animation hook.** `case screenshot` to `SneakContentType`. On new file: `coordinator.toggleExpandingView(status: true, type: .screenshot)` if enabled. Build `ScreenshotLiveActivity` view. Extend `ContentView.NotchLayout()` and `computedChinWidth`.
4. **Tab plumbing (empty body).** `case screenshots` in `NotchViews`. New `TabModel` (camera icon). Stub `ScreenshotTrayView` returning `Color.clear`. Wire `ContentView` switch.
5. **Thumbnail strip.** `ScreenshotThumbView` using existing `ThumbnailService`. `ScreenshotTrayViewModel` exposing `items` + `visibleItems`. Horizontal `ScrollView` + "+ show more" cell.
6. **Tap-to-reveal "Open folder" affordance.** Background-tap toggles `@State`. Hides on drag-begin via `vm.dragDetectorTargeting` flag.
7. **Pinned-folder grid (read-only).** `PinnedFolderCellView` (icon-only, hover→name). `PinnedFoldersStore` reads `Defaults`. "+" cell opens `NSOpenPanel`. Overflow popover for >8.
8. **Per-thumb hover quick actions + right-click menu.** Mirror `ShelfItemView`. `ScreenshotPasteboardService.copyImage(url:)` / `.copyFile(url:)`. Quick Look reuses existing `QuickLookService`.
9. **Drag-out (move/copy with Option).** `ScreenshotDraggableView` mirroring `DraggableClickView`. `NSDraggingSource` returns `[.copy, .move]`; `ignoreModifierKeys` returns `false` (Finder-default). Inside-app drops on pin cells: peek `NSEvent.modifierFlags.contains(.option)`. Cross-app drops: system handles via Finder convention.
10. **Toast + undo.** `UndoOp(from:to:)` stack. Show toast 5s on move success. Undo moves file back.
11. **Sandbox / first-run flow.** First click on camera tab: create folder if missing, prompt `NSOpenPanel` titled "Choose your screenshots folder" (default `~/Pictures/Notchdock Screenshots`), store bookmark. Don't gate app startup.
12. **Settings page.** Enable toggle, watched-folder picker, hint card ("Point macOS at this folder via ⌘⇧5 → Options → Save to" with a small disclosure showing the path), pinned folders list with add/remove/reorder, capture-animation toggle, items-visible stepper.
13. **Polish edge cases.** Stability check, duplicate handling, large screenshots, external removal, watched-folder-deleted recovery.

## Risks

### Sandbox + screencapture interaction
- macOS `screencapture` daemon runs outside our sandbox. Even when it writes into the watched folder, we can't read until the user grants access via `NSOpenPanel`. Non-optional. First-run flow must obtain a user-blessed bookmark.
- We do **not** try to programmatically change `com.apple.screencapture location`. The user manages this themselves via ⌘⇧5 → Options → Save to (decision 1). Removes the entire sandbox-subprocess-exec risk.

### FSEventStream vs. DispatchSourceFileSystemObject
- Choose `FSEventStream`: documented Apple-blessed directory watcher, supports `kFSEventStreamCreateFlagFileEvents` for per-file granularity, supports root-change detection, works across volumes. DSFSO requires an open fd on the dir and misses some events on certain macOS versions.
- Latency: configure 0.1s coalesce (default 1s).

### Notch state-machine conflicts
- `ContentView.handleHover` (line 513) collapses the notch on hover-out. A drag-out from a thumb leaves the hover area before drop completes — risk: notch closes mid-drag.
- **Mitigation:** set `vm.dragDetectorTargeting = true` for the drag session, mirroring `ShelfItemView.swift:67`.
- Expanding-view auto-hide cancellation (line 286): if a second screenshot arrives during the first's animation, the prior task is cancelled. Verified safe.

### Upstream merge friction
- Modifications touch upstream-active files (`ContentView.swift`, `BoringViewCoordinator.swift`, etc.).
- **Mitigation:** every modification is **additive** (new case, new branch, no reorder/delete). New code lives under dedicated `boringNotch/components/Screenshots/` directory upstream never touches.

### Performance
- A folder with hundreds of screenshots could freeze on first load.
- **Mitigations:** lazy thumbnail loading (existing `ThumbnailService` handles this), `screenshotTrayMaxVisible` cap, FSEvents coalescing prevents thumb generation storms.

### Drag operation modifier semantics
- For inside-app pinned-folder drops we read `NSEvent.modifierFlags.contains(.option)`. For cross-app, macOS chooses based on destination (Finder default: move within volume, copy across).
- Risk: cross-volume moves silently become copies. Acceptable per macOS convention. Toast should reflect actual op via `draggingSession(_:endedAt:operation:)`.

### Capture animation timing
- Existing `expandingView` auto-clears in 2–3s; we want ~0.5s.
- **Mitigation:** add `.screenshot` to the duration switch at `BoringViewCoordinator.swift:284`:
  `let duration: TimeInterval = (expandingView.type == .download ? 2 : (expandingView.type == .screenshot ? 0.5 : 3))`.

### `.draggable` vs. `NSDraggingSource`
- SwiftUI `.draggable` is available (macOS 13+) but lacks `ignoreModifierKeys` and full operation-mask control.
- **Mitigation:** stick with the AppKit pattern proven in `ShelfItemView.swift`.

## Verification

Manual smoke test sequence:

1. Build & run. Menubar → Settings → Screenshots tab visible.
2. Toggle "Enable screenshot tray" on. NSOpenPanel for folder. Accept default `~/Pictures/Notchdock Screenshots`.
3. Open macOS screenshot tool (⌘⇧5) → Options → Save to → pick the same folder. Take a ⌘⇧4 screenshot — file lands in watched folder.
4. Within ~1s: notch chin breathes ~40% taller for ~0.5s with thumb + "saved ✓".
5. Open notch. Three tabs: home, shelf, camera. Click camera — new screenshot is first thumb.
6. Hover thumb → quick-action overlay (copy image / copy file / reveal / ⋯).
7. Right-click thumb → context menu, all 5 items. Press space → Quick Look.
8. "Copy image", switch to Claude Desktop, ⌘V → image pastes inline.
9. "Copy file" in Slack, ⌘V → file uploads as attachment.
10. Add pin via "+" → pick `~/Desktop/inbox`. Cell appears.
11. Drag thumb onto pin (no modifier) → file moves; thumb disappears; toast "Moved to inbox · Undo" 5s. Click Undo → file returns; thumb reappears.
12. Drag with **Option held** → file copies; thumb stays; no toast.
13. Drag thumb to Finder window → file moves (Finder convention).
14. Drag thumb to Photos.app → file copies (cross-app destination).
15. Click strip background (not on a thumb) → "Open folder" affordance fades in. Begin drag → affordance hides.
16. Take 13+ screenshots → "+ show more" appears; expands strip in-place.
17. Delete a screenshot in Finder → thumb disappears within ~1s.
18. Quit + relaunch → state persists: pinned folders, watched folder, applied flag.

Spot checks:

- Console.app filtered by app — no `Operation not permitted` log entries.
- Bookmarks renew if user moves the watched folder (existing `Bookmark.resolve()`).

## Out of scope

- iCloud / cloud sync.
- Annotation / markup before saving (Apple's ⌘⇧5 UI handles this).
- Capture initiated by our app — observe only.
- Video / screen-recording (`.mov` filtered out).
- Batch ops (multi-select drag-out).
- Reorder of thumbs (always sorted by `addedAt` desc).
- Per-thumb badges beyond relative-time.
- Auto-cleanup of the watched folder.
- Localization for non-English locales — Xcode emits keys; translators handle later.
- Existing `ShelfView` ("airdrop" tab) is untouched.
- Programmatic management of macOS's screenshot save location — user controls it via ⌘⇧5 → Options.

## Rollback

- All changes additive; new files under `boringNotch/components/Screenshots/`, `boringNotch/managers/ScreenshotManager.swift`, `boringNotch/observers/ScreenshotFolderWatcher.swift`.
- `git revert` of feature commits restores upstream behaviour.
- No data migration. No schema change.
- Persisted state to clean up (manual): `UserDefaults` keys with `screenshot…` prefix.
- Watched folder on disk left intact (user data).
- macOS screenshot save location was never modified by us — nothing to restore.
