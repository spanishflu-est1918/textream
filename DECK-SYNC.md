# Deck Sync

Open Settings → Deck Sync, set the server URL (default `http://localhost:8123`; from the reading Mac use `http://supergorkbookpro:8123`, the recording Mac, over Tailscale), click **Apply URL**, and enable **Deck Sync**. In the main window click **Start Prompter** (or Command-Return). The enable switch and URL persist across launches. Deck Sync takes priority over Director Mode. Turning it off stops the connection and dismisses the live overlay; the original document is still available, unchanged.

The prompter follows the server's current slide, including the initial position sent on connection. Timeline positions resolve event keys to segment text. Empty scripts, unmatched/empty segments, and invalid positions retain the last text. Only changed text resets speech tracking and scrolling; duplicate events do not. A subtle section/slide counter appears in the main window. At the end of a passage the overlay stays visible, waiting for the next cue. Existing reading modes, external display, browser output, and appearance settings remain available.

A disconnected deck keeps its last text and displays **deck offline** in the main window, settings, and native prompter displays. Retries use 1, 2, 5, then 5 seconds. Requests time out after 30 seconds without incoming data. Reload messages fetch the deck again and resolve the current position. Changing URL or disabling cancels the previous stream and pending retries; a generation token rejects stale results. HTTP errors, malformed events, and unsupported messages cannot clear the script. There are no new dependencies.

## Files

- `Textream/Textream/DeckSync.swift`: Codable data, text resolution, streaming URLSession client, reload/reconnect/cancellation.
- `Textream/Textream/DeckSyncViews.swift`: settings, deck preview/start panel, offline indicator.
- `Textream/Textream/TextreamService.swift`: isolated deck source and shared existing page-update/reset path.
- `Textream/Textream/NotchSettings.swift`, `SettingsView.swift`, `TextreamApp.swift`, `ContentView.swift`: persisted configuration, startup, and UI integration.
- `Textream/Textream/NotchOverlayController.swift`, `ExternalDisplayController.swift`: retain completed deck passages, reset scrolling even for equal-length replacements, offline status.
- `Textream/Info.plist`: local HTTP networking and explicit localhost/cyberyogin/supergorkbookpro ATS exceptions. Other fully qualified HTTP hosts may need their own narrow exception; HTTPS works without one.
- `tests/deck-sync/Checks.swift`, `run.py`: standalone macOS CLI regression checks and a local HTTP/SSE fixture.

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for `Textream/`, attached to the macOS target. Both new Swift files are automatically included; no manual project entries are needed. The existing sandbox entitlement already includes `com.apple.security.network.client`. Release is unsandboxed; the Developer ID entitlement does not enable sandboxing.

## Checks performed

- Read-only requests to the running localhost deck and SSE endpoints confirmed the real JSON and initial `goto` format.
- `swiftc -typecheck` passed for `DeckSync.swift` against the installed macOS SDK.
- Both new files typechecked together with small temporary UI-model stubs (to isolate them from toolchain limitations).
- `python3 tests/deck-sync/run.py` passed: slide/timeline resolution, absent optional fields, invalid indices, empty retention, ignored/malformed events, duplicate suppression, actual SSE streaming, reload, EOF/offline retention, retry timing, and cancellation.
- All macOS Swift sources passed syntax parsing. Info.plist, project.pbxproj, and sandbox entitlements passed `plutil -lint`; `git diff --check` passed.
- Full-app typechecking was attempted. Command Line Tools Swift 6.1.2 lacks the SwiftUI Preview macro plugin and the newer default MainActor isolation setting used by this project. A full build is not claimed.

## When Xcode is installed

Build and run the macOS target with a toolchain supporting the project's default MainActor isolation setting. Verify Debug/AppStore sandbox networking and generated Info.plist/entitlements, local-network permission, localhost and Tailscale access. Run a real recording through normal slides, timeline gaps, edits/reload, server restart, URL changes, and enable/disable. Check microphone highlighting, equal-length script resets in each reading mode, notch/floating/fullscreen and external/browser displays, dismissal/restart, and preservation of the open document.

## Git delivery limitation

This session's filesystem policy makes `.git` read-only. `git switch -c deck-sync` failed with “Operation not permitted” creating the branch lock, so the implementation remains in the working tree on `master`; no commit or push was made. In a session with Git write access, create `deck-sync`, stage the files listed above plus this guide (and the supplied brief if desired), and commit as `SPANISH FLU <mrflu1918@proton.me>` with message `Add Deck Sync mode for live slide and timeline scripts`. Do not push.
