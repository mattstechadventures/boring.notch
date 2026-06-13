# Notch Utility Panels — Notes, Clipboard, Tasks, Files

Spec + implementation guide for four local utility panels in the open notch, written so the
work can be re-implemented cleanly on a fresh branch. Includes the **lessons** from the first
attempt so the same traps are avoided.

---

## 1. Scope & decisions

**Phase 1 = four fully-local panels.** No network, no third-party accounts.

| Panel | What it does |
|-------|--------------|
| **Notes** | Paste/type a note. Big blobs become one note. Title auto-derived from the first non-empty line, but **editable** (rename). Expandable detail view for the full body. |
| **Clipboard** | History of copied items, newest first. Click a row to copy it back. Per-row delete + Clear All. |
| **Tasks** | Plain local checklist: add, tick, delete, clear-done. |
| **Files** | Pinned folders (security-scoped). Click a folder to browse contents, click a file to open, drag files out to Finder and external files in. |

**Locked decisions (agreed with user):**
- **Note titles = first line, editable.** No LLM summarisation (that's a future drop-in; the title field is editable either way).
- **No note-platform sync** (Apple Notes / Notion / Obsidian). Apple Notes has no public API and is sandbox-hostile — explicitly deferred. Leave a `source` seam on the model only.
- **No task integrations** (Todoist / Outlook / Scoro) yet. Each is its own OAuth connector — Phase 2. Leave a `source` seam only; introduce a `TaskProvider` protocol *when the first connector lands*, not before.
- **Clipboard images** are session-only (shown but not persisted across launch).

---

## 2. Hard constraint: the app is sandboxed

`boringNotch/boringNotch.entitlements` has `com.apple.security.app-sandbox = true`. This is fine
for all four panels but dictates *how*:

- **Clipboard** — `NSPasteboard` is system-shared; works with no extra entitlement.
- **Files** — needs **security-scoped bookmarks** (already implemented in
  `components/Screenshots/Models/PinnedFolder.swift` + `components/Shelf/Models/Bookmark.swift`)
  and `NSOpenPanel` (allowed by the existing `files.user-selected.read-write` entitlement).
- **Notes / Tasks** — plain local JSON, trivial.

No entitlement changes are required for any of this.

---

## 3. Reuse — do NOT reinvent these

The codebase already contains almost everything:

- **`PinnedFolder` already exists** — `components/Screenshots/Models/PinnedFolder.swift`
  (`{ id, displayName, bookmark: Data }`, `Defaults.Serializable`) and a working store
  `components/Screenshots/Services/PinnedFoldersStore.swift` with `addPin()` (NSOpenPanel for
  directories), `remove`, `resolveURL`, and Combine autosave. **Files reuses this model** —
  do not declare a second `PinnedFolder`.
- **JSON persistence pattern** — `components/Shelf/Services/ShelfPersistenceService.swift`
  (load/save a `Codable` array to `~/Library/Application Support/boringNotch/<dir>/<file>.json`).
  Generalise it once into a `CodableFileStore<T>` and reuse for Notes/Tasks/Clipboard.
- **First-line title logic** — already inlined in `components/Shelf/Models/ShelfItem.swift`
  (`TextBlockData.displayTitle`, ~lines 77–86). Extract to a `String.titleFromFirstLine()` helper.
- **File drag/drop helpers** — `extensions/NSItemProvider+LoadHelpers.swift`
  (`extractFileURL()`), `extensions/URL+SecurityScoped.swift` (`accessSecurityScopedResource`),
  `Bookmark` (create/resolve), `GeneralDropTargetDelegate`.
- **Singleton ObservableObject manager pattern** — e.g. `managers/ClaudeCodeManager.swift`
  (`@MainActor final class … : ObservableObject`, `static let shared`, `@Published`).
- **Per-feature settings toggle** — `Defaults.Key` in `models/Constants.swift`,
  `Defaults.Toggle` in a settings view.

---

## 4. ⚠️ LESSONS FROM THE FIRST ATTEMPT (read first)

These three caused all the pain. Avoid them up front.

### Lesson 1 — NEVER build with `CODE_SIGNING_ALLOWED=NO` to run the app
`CODE_SIGNING_ALLOWED=NO` skips the codesign step, and **codesign is what applies the
entitlements**. The result is an app with **no entitlements → runs un-sandboxed**, which:
- reads `UserDefaults` from the wrong location (`~/Library/Preferences/…` instead of its
  sandbox container `~/Library/Containers/theboringteam.boringnotch/…`), so `firstLaunch`
  reads `true` → the **Welcome/onboarding window appears** (it never should on an established install), and
- runs under a different TCC permission identity → **Screen Recording isn't granted → the
  notch can't detect/align to the physical notch → it renders detached/"broken."**

**Build the normal ad-hoc way** (the project's `CODE_SIGN_IDENTITY[sdk=macosx*] = "-"` signs
ad-hoc with no Apple ID/team needed) so entitlements ARE applied and the app is sandboxed:

```
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug \
  -derivedDataPath build_run build
open build_run/Build/Products/Debug/boringNotch.app
```
or just press **⌘R in Xcode**. Verify with:
`codesign -d --entitlements - <app>` → must list `com.apple.security.app-sandbox`.

> Signing identities are a non-issue: ad-hoc (`-`) needs no Apple ID, team, or certificate.
> `security find-identity` showing "0 valid identities" is normal and irrelevant here.

### Lesson 2 — New files must live under a *synchronized root group*
This project's top-level source folders (`managers/`, `utils/`, `components/Settings/`, etc.)
are **regular Xcode groups with explicit file references** — new files dropped there are **NOT
compiled** (silent: you get "cannot find X in scope" only at the first referencing file in the
target, and the build bails before showing the rest).

Only specific feature folders are `PBXFileSystemSynchronizedRootGroup`s (auto-include
everything on disk, recursively): `components/Screenshots`, `components/Pomodoro`,
`components/FocusMusic`.

**Fix used:** put ALL new files under one new folder `components/UtilityPanels/` and register
it as a synchronized root group. That needs three `project.pbxproj` edits mirroring Pomodoro
(use a fresh UUID, e.g. `A1B2C3D4E5F6000000000003`):
1. A `PBXFileSystemSynchronizedRootGroup` object with `path = components/UtilityPanels;`.
2. Add its UUID to the `boringNotch` PBXGroup `children`.
3. Add its UUID to the target's `fileSystemSynchronizedGroups`.

(Alternative: register each new file with explicit `PBXFileReference` + `PBXBuildFile` entries —
more error-prone. The single synchronized folder is cleaner.)

### Lesson 3 — Utility entry points go in the RIGHT-side header cluster, NOT the tab bar
The left tab bar (`components/Tabs/TabSelectionView.swift` `tabs` array, rendered by
`TabButton`) is **icon-only with 30px horizontal padding per tab and no width management**.
Adding 4 tabs took it from 4→8 and it overran the notch cutout — visually broken.

The correct pattern is how **Pomodoro** and **FocusMusic** already work: 30×30 capsule
icon-buttons in the **trailing** `HStack` of `components/Notch/BoringHeader.swift`
(~lines 45–128), each gated by its `Defaults` enable key. Put the four utility buttons there.

---

## 5. File layout (target structure)

All new code under one synchronized folder:

```
boringNotch/components/UtilityPanels/
  Shared/
    CodableFileStore.swift      # generic JSON-array store
    TitleFromText.swift         # String.titleFromFirstLine()
    ModulesSettings.swift       # Settings page with the 4 enable toggles
  Notes/
    NoteItem.swift              # model (customTitle?, body, source: .local)
    NotesViewModel.swift        # @MainActor singleton, CodableFileStore<NoteItem>
    NotesView.swift             # list + paste bar
    NoteDetailView.swift        # editable title + body
  Clipboard/
    ClipboardItem.swift         # text/link persisted, image session-only
    ClipboardManager.swift      # NSPasteboard polling
    ClipboardView.swift
  Tasks/
    NotchTask.swift             # model (source: .local)
    TasksViewModel.swift
    TasksView.swift
  Files/
    FilesViewModel.swift        # reuses Screenshots' PinnedFolder
    FilesView.swift
```

---

## 6. Wiring points (edits to existing files)

1. **`enums/generic.swift`** — add cases to `NotchViews`: `.notes, .clipboard, .tasks, .files`.
2. **`ContentView.swift`** — in the `switch coordinator.currentView` (~line 384) add the four
   cases rendering `NotesView()`, `ClipboardView()`, `TasksView()`, `FilesView()`.
3. **`models/Constants.swift`** — add `Defaults.Key`s:
   ```swift
   static let enableNotes      = Key<Bool>("enableNotes", default: true)
   static let enableClipboard  = Key<Bool>("enableClipboard", default: true)
   static let enableTasks      = Key<Bool>("enableTasks", default: true)
   static let enableFiles      = Key<Bool>("enableFiles", default: true)
   static let clipboardHistoryLimit = Key<Int>("clipboardHistoryLimit", default: 50)
   static let filesPinnedFolders    = Key<[PinnedFolder]>("filesPinnedFolders", default: [])
   ```
4. **`components/Notch/BoringHeader.swift`** — in the trailing `HStack`, BEFORE the Pomodoro
   block, add four buttons (one per panel) mirroring the Pomodoro/FocusMusic button exactly:
   ```swift
   if Defaults[.enableNotes] {
       Button { withAnimation(.smooth) { coordinator.currentView = .notes } } label: {
           Capsule().fill(.black).frame(width: 30, height: 30)
               .overlay {
                   Image(systemName: "note.text")
                       .foregroundColor(coordinator.currentView == .notes ? .white : .gray)
                       .padding().imageScale(.medium)
               }
       }.buttonStyle(PlainButtonStyle())
   }
   ```
   Icons: Notes `note.text`, Clipboard `doc.on.clipboard`, Tasks `checklist`, Files `folder.fill`.
   **Do NOT touch `TabSelectionView.swift`** and **do NOT** broaden the tab-bar visibility
   condition in `BoringHeader` (line ~19) — leave the tab bar at its original four tabs.
5. **`components/Settings/SettingsView.swift`** — add a sidebar `NavigationLink(value: "Modules")`
   and a `case "Modules": ModulesSettings()` in the detail switch.
6. **`boringNotchApp.swift`** — in `applicationDidFinishLaunching`, after
   `ScreenshotManager.shared.start()`, add `ClipboardManager.shared.start()` so polling begins
   at launch.

---

## 7. Key implementation notes per panel

### Shared — `CodableFileStore<T: Codable>`
`init(subdirectory:filename:)` → `~/Library/Application Support/boringNotch/<sub>/<file>`,
`load() -> [T]` (with best-effort per-item recovery), `save([T])` atomic, iso8601 dates.

### Notes
- `NoteItem { id, customTitle: String?, body, createdAt, updatedAt, source: NoteSource = .local }`;
  computed `title` = `customTitle` (if non-empty) else `body.titleFromFirstLine()` else "Untitled".
- `enum NoteSource: String, Codable { case local }` — the deferred-sync seam.
- `NotesViewModel` (`@MainActor`, `static let shared`): `@Published private(set) var notes`,
  `add(text:)` prepends, `rename`, `updateBody`, `delete`, `deleteAll`, `move`; persist on each mutation.
- `NotesView`: header "Notes" + count badge + trash-all; scrollable rows (accent bar, title,
  chevron→detail, ✕→delete); bottom "New note…" multiline field with send button.
  `NoteDetailView`: back button (commits), editable title `TextField`, `TextEditor` for body;
  commit on disappear.
- **SwiftUI gotcha:** in a ternary mixing `.secondary` and `.orange` for `.foregroundStyle`,
  write `Color.secondary` / `Color.orange` explicitly — otherwise the two resolve to different
  ShapeStyle types and it won't compile.

### Clipboard
- `ClipboardManager` (`@MainActor`, `static let shared`): `Timer` ~0.5s watching
  `NSPasteboard.general.changeCount`. On change:
  - **Skip concealed/transient:** if `pasteboard.types` contains
    `org.nspasteboard.ConcealedType` / `TransientType` / `AutoGeneratedType` (password managers).
  - **Self-write guard:** `copyToPasteboard(_:)` writes then records the new `changeCount` in an
    `ignoreChangeCount` so the next poll doesn't re-capture our own write.
  - Dedup a consecutive duplicate of the newest entry; cap to `clipboardHistoryLimit`.
  - Start/stop the timer via `Defaults.observe(.enableClipboard)`; start in `applicationDidFinishLaunching`.
- `ClipboardItem { id, kind(.text/.link/.image), text: String?, image: NSImage?, createdAt }`.
  `image` is **excluded from Codable** via explicit `CodingKeys` (no `image`); persist only
  `isPersistable` items (text/link) — `store.save(items.filter(\.isPersistable))`.
- `ClipboardView`: "Clipboard" header + red "Clear All"; rows show preview + ✕; tap row → copy
  (brief "Copied!" feedback).

### Tasks
- `NotchTask { id, title, isDone, createdAt, source: TaskSource = .local }`,
  `enum TaskSource { case local }` (Phase-2 seam).
- `TasksViewModel`: `add`, `toggle`, `delete`, `clearCompleted`, `move`.
- `TasksView`: header + open-count badge + "Clear done"; checklist rows (circle toggle, title,
  ✕ on hover); "New task…" field.

### Files
- Reuse `PinnedFolder` (Screenshots). `FilesViewModel` (`@MainActor`, `static let shared`)
  mirrors `PinnedFoldersStore` but persists to its own `Defaults[.filesPinnedFolders]` via
  Combine autosave (`$pins.dropFirst().sink`):
  - `addPin()` (NSOpenPanel, dirs only) / `addPin(url:)` (dedupe by resolved path);
  - `select(_:)`, `reloadContents()` — list dir inside
    `folder.accessSecurityScopedResource { FileManager.contentsOfDirectory(... skipsHiddenFiles) }`,
    sorted by localized name;
  - `open(_:)` — `NSWorkspace.shared.open` for files, `activateFileViewerSelecting` for folders;
  - `importFiles(_:)` — copy dropped files into the selected folder within the security scope.
- `FilesView`: header + `+` (pin); horizontal pinned-folder chips (tap to select, minus to
  remove); contents list (icon via `NSWorkspace.shared.icon(forFile:)`, tap to open,
  `.onDrag { NSItemProvider(object: url as NSURL) }` to drag out); `.onDrop(of: [.fileURL])` on
  the contents area to import; orange border while drop-targeted.

---

## 8. Verification

1. **Build the sandboxed way** (Lesson 1): `xcodebuild … build` (no `CODE_SIGNING_ALLOWED=NO`)
   or ⌘R. Confirm `codesign -d --entitlements -` lists `app-sandbox`. App should launch with
   **no Welcome screen** and a **correctly-positioned notch**.
2. **Placement:** open notch → left tab bar unchanged (Home/Shelf/Screenshots/Claude); the four
   new icons sit in the **right** cluster next to timer/music.
3. **Notes:** paste a long blob → title = first line; open → rename + edit body; relaunch → persists.
4. **Clipboard:** copy several things → newest-first; password-manager field → does NOT appear;
   click row → back on clipboard, not duplicated; Clear All; relaunch → text/links persist.
5. **Tasks:** add/tick/clear-done; relaunch → persists.
6. **Files:** pin a folder → browse → open a file → drag out → drag in → relaunch (bookmark resolves).
7. **Settings → Modules:** toggling a panel adds/removes its right-side button.

---

## 9. Future phases (out of scope for Phase 1)
- **Task connectors** (Todoist → Microsoft Graph/Outlook → Scoro): one `TaskProvider`
  implementation each, OAuth + Keychain token + poll, aggregated into one filtered list with
  source badges. Introduce the protocol when the first one lands.
- **Note sync**: prefer Notion / watched plain-text (Obsidian) folder over Apple Notes (no API).
- **LLM note titles**: drop-in upgrade to the editable title field (needs network + API key).
- **Right cluster crowding**: if ~9 icons feels tight on smaller notches, collapse the utility
  set behind one "more" button.
