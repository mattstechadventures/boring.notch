# Notch Utility Panels v2 — Header Layout System, Panels & Default-View

This is the **v2 plan**: a rebuild on a fresh branch (`feat/notch-utility-panels-v2`) after the
first attempt broke the notch. It supersedes the structure of the original spec but **reuses its
per-panel implementation detail** — see [`notch-utility-panels.md`](./notch-utility-panels.md) for
the Notes/Clipboard/Tasks/Files internals (models, view models, gotchas). This doc adds the part
that was missing the first time: a **notch-header layout system** so entry points can never again
overflow the notch.

Structure (as agreed): a **breakdown of each piece** (§3), then a **collective build plan** (§5).

---

## 1. Why v2 — what actually broke

The first attempt added icons to the header and the notch "expanded past its borders, cutting
things off; Home disappeared entirely." Verified root cause in code:

- The open panel is a **fixed 640pt** (`boringNotch/sizing/matters.swift:16` →
  `openNotchSize = 640×190`).
- `components/Notch/BoringHeader.swift` lays out **left cluster → center notch mask → right
  cluster**, where each side cluster is `.frame(maxWidth: .infinity, alignment: .leading/.trailing)`.
  That bounds the *frame* but **not the intrinsic width of the buttons inside**. Add enough buttons
  and their natural width exceeds the half-region; SwiftUI doesn't clip, so content renders past the
  640 boundary and siblings (like Home) get pushed off.
- There is **no width cap** anywhere on the header (`BoringHeader()` in `ContentView.swift` only
  constrains height).

**The fix is structural:** render only as many slot items per side as physically fit, computed from
live geometry. If the renderer *cannot* draw more than fits, the bug cannot recur — on any display.

Carry over the three hard lessons from the original doc §4 (they still apply verbatim):
1. **Build ad-hoc** (never `CODE_SIGNING_ALLOWED=NO`) so the sandbox/entitlements apply.
2. **New files must live under a `PBXFileSystemSynchronizedRootGroup`** (`components/UtilityPanels/`
   — already registered in `project.pbxproj`, do NOT re-add).
3. Entry points go in the **header clusters**, not the legacy tab bar — and now, specifically, in
   **geometry-bounded slots**.

---

## 2. Locked decisions (from discussion)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Scope of slot system | **Unified** — all header entry points (Home/Shelf/Screenshots/Claude + Pomodoro/FocusMusic/webcam/settings/battery + the 4 new panels) become registry-driven slot items. |
| D2 | Capacity | **Geometry-derived & asymmetric**, computed per-display (≈4 left / 5 right on the reference 14"/16"). Not hardcoded. |
| D3 | Overflow safety | **Saved layout = intent; render clamps to live per-display capacity.** Left→right order = survival priority. Clamped items are hidden (no "more" button in v1). |
| D4 | "MAX" | **MAX = number of ghost slots a side uses**, capped at geometric capacity; user can dial *down*. No separate abstract number. |
| D5 | Elastic padding | **Per-side toggle.** Slack distributed as inter-icon gap up to `maxGap`; group anchored to the outer edge (packs away from the notch). |
| D6 | Management UI | **Settings-only**, per-side independent, **drag-to-slot** editor with ghost squares, a palette of unplaced panels, and a **WYSIWYG notch preview**. |
| D7 | Left/right semantics | **Free placement** (personal preference) — no enforced nav-left/tools-right rule. |
| D8 | Always-on cores | **Home and Settings are pinnable** — default-on, un-removable, **but still movable/reorderable** — so you can't configure away navigation or access to settings. Everything else free. |
| D9 | Per-feature settings | Each panel owns **its own settings section** (registry-driven), not one shared "Modules" page. |
| D10 | Default-view | A **default-open policy** (fixed / last-viewed / smart-active-context) that unifies today's scattered `focusMusicAutoOpenTab` / `openShelfByDefault` / `openLastTabByDefault` flags. |

---

## 3. Breakdown of each piece

### 3.A — The four utility panels (Notes, Clipboard, Tasks, Files)

Unchanged from the original spec — implement per
[`notch-utility-panels.md`](./notch-utility-panels.md) §5–§7. Summary:

- **Notes** — paste/type; title = first line (editable); detail view. `NoteSource = .local` seam.
- **Clipboard** — `NSPasteboard` polling (~0.5s), concealed-type skip, self-write guard, dedup, cap;
  images session-only (excluded from `Codable`).
- **Tasks** — local checklist; `TaskSource = .local` seam.
- **Files** — reuse Screenshots' `PinnedFolder` + security-scoped bookmarks; pin/browse/open/drag.

Shared infra: `CodableFileStore<T>` (generalize `ShelfPersistenceService`) and
`String.titleFromFirstLine()` (extract from `ShelfItem.TextBlockData.displayTitle`). All under the
already-registered synchronized group `components/UtilityPanels/`.

> These four are *tenants* of the layout system below — they register descriptors and otherwise
> behave like any other slot item.

### 3.B — Architecture backbone: the Panel Registry

One declaration per header entry makes per-feature settings, slot placement, and default-view all
fall out as data over the registry.

```swift
enum PanelSide { case left, right }
enum PanelKind { case view(NotchViews)   // opens a notch view
                 case action             // e.g. toggle webcam, open settings window
                 case indicator }        // e.g. battery (display-only, still occupies a slot)

struct PanelDescriptor: Identifiable {
    let id: PanelID                       // .home, .shelf, .notes, .clipboard, .tasks, .files,
                                          // .pomodoro, .focusMusic, .webcam, .settings, .battery …
    let label: String
    let icon: String                      // SF Symbol
    let kind: PanelKind
    let defaultSide: PanelSide
    let isPinnable: Bool                  // Home, Settings = true (un-removable, still movable)
    let enableKey: Defaults.Key<Bool>?    // per-panel on/off (nil = always available)
    let isActiveContext: () -> Bool       // for smart default-view (e.g. FocusMusic.isPlaying)
    let settingsSection: (() -> AnyView)? // per-feature settings page (§3.F)
}
```

A `PanelRegistry` (singleton) holds all descriptors. **Heterogeneous slots:** view/action/indicator
items share the slot model but differ in tap behavior; indicators (battery) are placeable but not
"opened." Icons: Notes `note.text`, Clipboard `doc.on.clipboard`, Tasks `checklist`, Files
`folder.fill` (existing icons reused for the legacy entries).

### 3.C — Notch geometry & per-side capacity

Available width per side, within the 640 panel, around the centered notch mask:

```
notchW          = vm.closedNotchSize.width            // per-display, from auxiliaryTop*Area
sideRegionW     = (openNotchSize.width - notchW) / 2 - outerMargin
capacity(side)  = max(0, floor((sideRegionW + minGap) / (iconW + minGap)))   // iconW = 30
```

`closedNotchSize.width` already varies per display via `getClosedNotchSize(screenUUID:)`
(`sizing/matters.swift`), so `capacity` is naturally per-display. On the reference Mac this yields
≈4 left / 5 right, matching the screenshot. A `HeaderLayoutManager` (singleton, `@MainActor`)
exposes `capacity(_:)` and recomputes on screen change (observe `selectedScreenUUID` /
`NSApplication.didChangeScreenParametersNotification`).

> The left side currently *looks* roomier because legacy `TabButton` uses 30pt horizontal padding
> (`TabButton.swift`) vs the right cluster's 4pt spacing. Under the unified model both sides use the
> same icon+gap math, so capacity is consistent and predictable.

### 3.D — Header layout fix (the safety guarantee)

`BoringHeader` is reworked to render from the layout manager:

1. Read the saved arrangement: ordered `[PanelID]` for `.left` and `.right` (intent, §4).
2. Filter to *enabled* panels (per `enableKey`).
3. **Clamp** each side to `capacity(side)` for the **current display**, keeping the first N in order
   (pinned items — Home — are kept first / never clamped out).
4. Render exactly those, with elastic padding (§3.E). Nothing else is drawn → **overflow is
   structurally impossible.**

This replaces the legacy `TabSelectionView` left cluster and the hardcoded right `HStack`. The tab
bar's array is migrated into registry descriptors; `TabSelectionView` is retired or reduced to a thin
renderer. (Lesson-3 caution from the original doc — destabilizing the tab bar — is the reason this is
L3 and gets a reviewer pass.)

### 3.E — Elastic padding

Per-side toggle (D5). Given `n` placed icons in `sideRegionW`:

```
slack  = sideRegionW - n*iconW
gap_on  = min(maxGap, slack / max(1, n-1))     // elastic ON: spread, capped at maxGap
gap_off = minGap                               // elastic OFF: fixed minimum
```

- `maxGap` = a tuned constant chosen to match the current comfortable left-cluster spacing ("the
  4-wide spacing is the max"). With fewer icons than capacity, the gap **caps at `maxGap`** and the
  group **anchors to the outer edge** (away from the notch), leaving clean empty space beside the
  cutout rather than over-stretching.
- Implemented as computed spacing on the side `HStack` (or interleaved `Spacer(minLength:)` with a
  `.frame(maxWidth:)` cap), plus outward alignment.

### 3.F — Per-feature settings sections (D9)

Settings IA becomes registry-driven. In `components/Settings/SettingsView.swift`, the sidebar gains:

- A **"Notch Layout"** section (the editor, §3.G + default-view §3.G2).
- One section **per panel** that has a `settingsSection` (Notes / Clipboard / Tasks / Files, plus
  existing Pomodoro/FocusMusic already have their own). Rendered by iterating the registry — adding a
  5th feature later automatically appears here, no SettingsView edit.

This replaces the original doc's single `ModulesSettings` page.

### 3.G — Notch Layout editor (drag-to-slot, WYSIWYG)

A SwiftUI editor in the new "Notch Layout" settings section:

- **Two slot rows** (left / right) rendered as the **real ghost-slot count for the current display**
  (capacity from §3.C), with the **`NotchShape` drawn between them** so it reads as the actual notch.
- A **palette** below: chips for every enabled-but-unplaced panel.
- **Drag** a chip from palette → a ghost slot to place; **drag between slots** to reorder / move
  side; **drag back to palette** to remove (pinned **Home and Settings** can be moved/reordered but
  not removed — D8).
- **Live preview** reflects elastic padding (§3.E) and the per-side elastic toggles, so it's WYSIWYG.
- Per-side controls: **elastic on/off** and **MAX = used slot count** (≤ capacity, D4).
- Reuse the reorder interaction already built for Focus Music list management (recent commit
  `789c602`).

#### 3.G2 — Default-view ("default open") management (D10)

Today this is scattered: `currentView` defaults `.home` (`BoringViewCoordinator.swift:54`);
`BoringViewModel.open()` forces `.focusMusic` when `enableFocusMusic && focusMusicAutoOpenTab &&
FocusMusicManager.isPlaying`; `close()` honors `openShelfByDefault` and a half-built
`openLastTabByDefault` (which never actually restores the last view). Unify into one policy:

```swift
enum DefaultViewPolicy: Codable {
    case fixed(PanelID)   // always open a chosen panel (e.g. .home, .notes)
    case lastViewed       // restore the panel you last had open
    case smart            // open the highest-priority panel whose isActiveContext() is true,
}                         // else fall back to `smartFallback` (a PanelID)
```

- On `open()`, resolve the policy:
  - `.fixed` → set that panel.
  - `.lastViewed` → restore a persisted `lastView` (genuinely implement what `openLastTabByDefault`
    promised; persist `currentView` on close).
  - `.smart` → first registry panel (in user slot order) with `isActiveContext() == true`, else
    `smartFallback`. FocusMusic's `isActiveContext = { FocusMusicManager.shared.isPlaying }`
    reproduces today's music-auto-open as a *configurable* rule; Shelf's
    `= { !ShelfState.isEmpty }` reproduces `openShelfByDefault`.
- **Migration:** map existing flags into the new policy on first run, then retire the individual
  Defaults (keep reading them once for migration). Editor UI: a picker (Fixed → panel chooser /
  Last viewed / Smart → fallback chooser) in the Notch Layout section.

---

## 4. Persistence model

New `Defaults.Key`s (in `models/Constants.swift`, plus the four `enable*` and `clipboardHistoryLimit`
/ `filesPinnedFolders` from the original doc):

```swift
static let headerLeftOrder   = Key<[PanelID]>("headerLeftOrder",  default: [.home, .shelf, .screenshots, .claudeCode])
static let headerRightOrder  = Key<[PanelID]>("headerRightOrder", default: [.pomodoro, .focusMusic, .settings])
static let headerLeftMax     = Key<Int>("headerLeftMax",  default: 0)   // 0 = use full capacity
static let headerRightMax    = Key<Int>("headerRightMax", default: 0)
static let headerLeftElastic  = Key<Bool>("headerLeftElastic",  default: true)
static let headerRightElastic = Key<Bool>("headerRightElastic", default: true)
static let defaultViewPolicy = Key<DefaultViewPolicy>("defaultViewPolicy", default: .smart)
static let defaultViewFallback = Key<PanelID>("defaultViewFallback", default: .home)
static let lastView          = Key<PanelID>("lastView", default: .home)
```

- **Layout is global intent** (one arrangement), **not per-display** — rendering clamps to whatever
  the current display fits (D3). This is what guarantees the original bug can't return when moving
  between a notch laptop and an external monitor.
- `PanelID` must be `Codable` + `Defaults.Serializable` (string raw value).

---

## 5. Collective build plan

Phased so the **riskiest geometry/header rework is proven before features pile on**, and each phase
leaves the project compiling. **L3** — `planner` (done) → build → `reviewer` + adversarial pass →
sandboxed real-env verification → log.

### Phase 0 — Hygiene & plumbing verify
- `rm -rf build_run/` (stale cache from the scrapped attempt).
- `mkdir -p boringNotch/components/UtilityPanels/{Shared,Notes,Clipboard,Tasks,Files,Header}`.
- **Verify** the three `project.pbxproj` synchronized-group entries already exist (UUID
  `A1B2C3D4E5F6000000000003`, lines ≈349/617/848) — **do not re-add**.
- Throwaway compile-probe in `Shared/` → build ad-hoc → confirm the synchronized group compiles new
  on-disk files → delete probe. *(Lesson 2 gate.)*

### Phase 1 — Registry + geometry foundation (no UI change yet)
- `Header/PanelID.swift`, `Header/PanelDescriptor.swift`, `Header/PanelRegistry.swift` (register the
  existing legacy entries first: home/shelf/screenshots/claudeCode/pomodoro/focusMusic/settings/…).
- `Header/HeaderLayoutManager.swift` — `capacity(_:)`, screen-change observation, clamp logic.
- Unit-check capacity math against known notch widths. **No visual change** — old header still in use.

### Phase 2 — Header rework (the safety fix)
- Rewrite `components/Notch/BoringHeader.swift` to render left/right from
  `HeaderLayoutManager` + registry, clamped to capacity, with elastic padding (§3.E).
- Migrate `TabSelectionView` content into registry descriptors; retire/thin the view.
- **Verify overflow is gone:** force a deliberately over-full arrangement → confirm clamping hides
  extras and Home (pinned) always survives. This is the core acceptance gate for "the bug is dead."

### Phase 3 — Shared layer + Notes + Tasks
- `Shared/CodableFileStore.swift`, `Shared/TitleFromText.swift`.
- Notes (`NoteItem`, `NotesViewModel`, `NotesView`, `NoteDetailView`) + Tasks
  (`NotchTask`, `TasksViewModel`, `TasksView`). Register their descriptors.

### Phase 4 — Clipboard
- `ClipboardItem`, `ClipboardManager` (start in `applicationDidFinishLaunching` after
  `ScreenshotManager.shared.start()`), `ClipboardView`. Register descriptor.

### Phase 5 — Files
- `FilesViewModel` (mirror `PinnedFoldersStore`, persist to `Defaults[.filesPinnedFolders]`),
  `FilesView`. Reuse Screenshots' `PinnedFolder`. Register descriptor.

### Phase 6 — Wiring the views
- `enums/generic.swift`: add `.notes/.clipboard/.tasks/.files` to `NotchViews`.
- `ContentView.swift`: add the four cases to the (exhaustive) `switch coordinator.currentView`.
- `models/Constants.swift`: add all `Defaults.Key`s (§4 + original doc's panel keys).

### Phase 7 — Settings: per-feature sections + Notch Layout editor
- Registry-driven sidebar sections (§3.F).
- `Header/NotchLayoutEditor.swift` — drag-to-slot ghost-slot editor + WYSIWYG notch preview +
  per-side elastic/MAX controls (§3.G).
- Default-view policy UI + `DefaultViewPolicy` resolution in `BoringViewModel.open()`; persist
  `lastView` on close; migrate & retire `focusMusicAutoOpenTab`/`openShelfByDefault`/
  `openLastTabByDefault` (§3.G2).

### Phase 8 — Sandboxed verification (Lesson 1) + review
- Build ad-hoc: `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug
  -derivedDataPath build_run build` → `open build_run/Build/Products/Debug/boringNotch.app`.
- `codesign -d --entitlements - <app>` must list `app-sandbox`; **no Welcome screen**; notch aligned.
- Walk the checklist (§6). Then `reviewer` + adversarial pass on the diff (esp. the BoringHeader /
  TabSelectionView rework).

---

## 6. Verification checklist

1. **Sandboxed & aligned** — entitlements present, no Welcome screen, notch positioned correctly.
2. **Overflow dead** — configure more enabled panels than fit; confirm each side clamps to capacity,
   extras hidden in priority order, **Home always present**; resize/switch displays → re-clamps live.
3. **Elastic** — toggle per side; fewer icons cap at `maxGap`, anchored outward; full count fills.
4. **Editor** — drag panel from palette → slot; reorder; move side; remove (Home can't be removed);
   preview matches the real notch after closing settings.
5. **Per-feature settings** — each panel has its own section; toggling enable adds/removes its slot.
6. **Default-view** — Fixed opens chosen panel; Last-viewed restores prior; Smart opens FocusMusic
   while playing else fallback; old flags migrated, behavior preserved.
7. **Panels** — Notes/Clipboard/Tasks/Files per original doc §8 (persist across relaunch; clipboard
   skips password fields; Files bookmark resolves).

---

## 7. Risks

- **Header rework destabilizes existing nav** (highest) — Phase 2 is isolated and gated by the
  overflow test before any feature work; reviewer + adversarial pass in Phase 8.
- **Heterogeneous slot items** (view/action/indicator — e.g. battery) need correct tap/no-tap
  behavior; model via `PanelKind`.
- **Duplicate pbxproj UUID** if plumbing re-added — Phase 0 is verify-only.
- **Stale `build_run/` cache** masking errors — deleted in Phase 0.
- **Lesson 1 regression** (un-sandboxed build) — only the ad-hoc command, verified via `codesign`.
- **Default-view migration** dropping a user's existing preference — migrate-then-retire, read old
  flags once.
- **Per-display capacity edge cases** — external/non-notch displays (virtual notch), capacity 0
  guard, screen hot-plug recompute.

## 8. Out of scope (future)
Task/note connectors & sync, LLM note titles, clipboard image persistence, a "more"/overflow popover
(D3 hides instead, for now), per-display *distinct* arrangements (global intent + live clamp for v1).
`source`/`TaskProvider` seams added but single-case.

## 9. Open questions
1. `maxGap` exact value — tune visually in Phase 2 against the screenshot's left-cluster feel.

### Resolved
- **Settings-gear** is **pinnable (required) but movable** — same as Home (D8). **webcam/battery**
  are movable *and* removable via their enable keys.
- **`defaultViewPolicy` defaults to `.smart`** (preserves today's music-auto-open feel as a
  configurable rule).
