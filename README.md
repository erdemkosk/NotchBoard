<p align="center">
  <img src="docs/assets/logo.png" alt="NotchBoard logo" width="160" height="160" />
</p>

<h1 align="center">NotchBoard</h1>

A native macOS menu-bar/notch utility. Move the mouse to the notch and a panel
expands with two tabs:

- **History** - clipboard history (text, links, images, files, colors). Click a
  card to re-copy it, or drag it straight into another app. The Transform menu
  (UPPERCASE, trim, beautify JSON, …) rewrites the item in place and copies it.
- **Shelf** - a drop zone parked under the notch, organized into named, colored
  **collections** (tabs you create with `+`). Drag files/images onto the notch
  to stash them, then drag them out into any app later. Multi-select tiles to
  zip, share (AirDrop / iCloud / Mail), move between collections, or drag them
  all out at once. You can also right-click files in Finder and choose
  **Send to NotchBoard** (see below).

On Macs/displays without a hardware notch, the trigger pill's width, height and
corner radius are customizable in Settings.

Built with **Swift + SwiftUI + AppKit** (no Tauri/web layer) because the core
features - notch window behavior, rich clipboard capture, and native
drag-and-drop *out* to other apps - all rely on first-class macOS APIs.

## Requirements

- macOS 14+
- Swift 6 toolchain (`swift --version`)
- Full Xcode is optional. The included `make-app.sh` assembles a runnable
  `.app` bundle using only the Command Line Tools.

## Build & run

```bash
# Dev build
swift build

# Release build + assemble dist/NotchBoard.app + ad-hoc sign
./make-app.sh release
open dist/NotchBoard.app
```

The app runs as a menu-bar accessory (no Dock icon). Use the menu-bar icon to
toggle the panel or quit. On Macs without a hardware notch, a small pill appears
centered under the menu bar as the trigger.

## Installation (downloaded release)

NotchBoard is only ad-hoc signed (not notarized with a paid Developer ID), so
macOS Gatekeeper will warn that the app is "damaged" or "from an unidentified
developer" the first time you open a downloaded build. This is expected.

To remove the quarantine flag and run it, move `NotchBoard.app` to
`/Applications` and run:

```bash
xattr -cr /Applications/NotchBoard.app
open /Applications/NotchBoard.app
```

`xattr -cr` clears the `com.apple.quarantine` attribute that macOS adds to apps
downloaded from the internet. You only need to do this once per download. If you
build the app yourself with `./make-app.sh`, this step is not needed.

## Finder integration ("Send to NotchBoard")

The app ships an embedded Finder Sync extension that adds a **Send to
NotchBoard** item to Finder's right-click menu. Because the app is only ad-hoc
signed, macOS won't auto-enable third-party extensions; turn it on once:

1. Launch `NotchBoard.app` at least once (ideally from `/Applications`).
2. Open **System Settings → General → Login Items & Extensions → Added
   Extensions → Finder** (older macOS: **Privacy & Security → Extensions**).
3. Enable **NotchBoard**.

Selected files are copied into the current Shelf collection. The extension
talks to the app via a small `inbox.json` in Application Support plus a Darwin
notification, so the app picks them up immediately if it's running (otherwise on
next launch).

## Project layout

```
Sources/NotchBoard/
  main.swift                 # NSApplication bootstrap (accessory app)
  App/AppDelegate.swift      # status item + window lifecycle
  Window/
    NotchWindow.swift        # borderless, all-Spaces, status-bar-level window
    NotchWindowController.swift  # open/close hover logic + geometry
    NotchScreenMetrics.swift # notch geometry (safeAreaInsets, aux areas)
    HoverDetector.swift      # global mouse tracking
  Views/
    NotchView.swift          # closed pill <-> expanded morph
    ExpandedPanel.swift      # search + tabs + content
    HistoryView.swift        # clipboard grid + cards
    ShelfView.swift          # shelf grid + drop target
    NotchViewModel.swift     # shared observable state
  Clipboard/
    ClipboardManager.swift   # NSPasteboard polling + persistence
    ClipboardItem.swift
  Shelf/
    ShelfManager.swift       # dropped-file cache + collections + persistence
    ShelfItem.swift
    ShelfCollection.swift    # named, colored shelf tabs
    DragProviders.swift      # NSItemProvider for outward drags
    MultiFileDragHandle.swift# AppKit multi-file drag-out
    ShareHelper.swift        # NSSharingServicePicker (AirDrop/iCloud/…)
    ZipArchiver.swift        # ditto-based zip of selected files
    ShelfInbox.swift         # receives files from the Finder extension
FinderExtension/             # FIFinderSync .appex (assembled by make-app.sh)
  FinderSync.swift
  Info.plist
  Store/Persistence.swift    # Application Support paths + JSON helpers
  Support/Extensions.swift   # color parsing helpers
```

## Advanced Features & Layout Refinements

Recently, several advanced features and layout refinements have been added to improve user experience and security:

- **Custom Hotkey Recorder**: Users can customize the keyboard shortcut to toggle/summon NotchBoard in Settings.
- **Auto-Paste (Direct Paste)**: Optionally automatically paste the copied clipboard item straight into the active frontmost app upon clicking.
- **Dynamic Template Snippets**: Supports `{date}`, `{time}`, and `{clipboard}` template tags inside custom snippets which resolve dynamically when copied.
- **Interactive Capture HUD (Notch Island Actions)**: Hovering over the notch notification HUD displays action buttons to **Undo** (delete item from history) or **Send to Shelf** directly.
- **Biometric Secured Shelf**: Mark any shelf collection as locked. Viewing a locked collection requires Touch ID or system password validation. The tab **automatically relocks** the instant the panel collapses, closes, or the app loses focus.
- **Stable Header & Layout (Anti-Jump)**: The navigation tab bar stays locked at the top of the expanded panel, and only tab-specific search fields or filter chips slide in below it, preventing visual jitter.
- **Layout Overlap & Alignment Fixes**: History and Shelf cards have been designed to use fixed-height card boundaries and strict thumbnail bounds to prevent elements from overlapping. Cards adapt into columns side-by-side even at narrower panel widths (down to 460pt width).
- **Hotkey Flow Refinement**: Summing the panel via the custom keyboard shortcut automatically switches focus to the History tab and selects the search field so you can type instantly.

## Project layout

```
Sources/NotchBoard/
  main.swift                 # NSApplication bootstrap (accessory app)
  App/AppDelegate.swift      # status item + window lifecycle
  Window/
    NotchWindow.swift        # borderless, all-Spaces, status-bar-level window
    NotchWindowController.swift  # open/close hover logic + geometry
    NotchScreenMetrics.swift # notch geometry (safeAreaInsets, aux areas)
    HoverDetector.swift      # global mouse tracking
  Views/
    NotchView.swift          # closed pill <-> expanded morph
    ExpandedPanel.swift      # search + tabs + content
    HistoryView.swift        # clipboard grid + cards
    ShelfView.swift          # shelf grid + drop target
    NotchViewModel.swift     # shared observable state
  Clipboard/
    ClipboardManager.swift   # NSPasteboard polling + persistence
    ClipboardItem.swift
  Shelf/
    ShelfManager.swift       # dropped-file cache + collections + persistence
    ShelfItem.swift
    ShelfCollection.swift    # named, colored shelf tabs
    DragProviders.swift      # NSItemProvider for outward drags
    MultiFileDragHandle.swift# AppKit multi-file drag-out
    ShareHelper.swift        # NSSharingServicePicker (AirDrop/iCloud/…)
    ZipArchiver.swift        # ditto-based zip of selected files
    ShelfInbox.swift         # receives files from the Finder extension
FinderExtension/             # FIFinderSync .appex (assembled by make-app.sh)
  FinderSync.swift
  Info.plist
  Store/Persistence.swift    # Application Support paths + JSON helpers
  Support/Extensions.swift   # color parsing helpers
```

## Notes / next steps

- Persisted state lives in `~/Library/Application Support/NotchBoard/`.
- Drag-out uses `NSItemProvider` file representations so receiving apps get real files; this can be upgraded to `NSFilePromiseProvider` for lazy generation.
- A future hardened/sandboxed build would add an entitlements file and proper Developer ID signing in `make-app.sh`.

