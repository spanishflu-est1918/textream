# Brief: make Textream follow the Dharma Cowboys deck

## Goal
This repo is our fork of Textream (MIT, upstream f/textream), a macOS teleprompter that shows a script under the MacBook notch and highlights the current line as you speak. We record a podcast from a slide deck. Add a **Deck Sync** mode: Textream shows the script for whatever slide (or timeline event) is currently on air, and switches automatically when the presenter changes slide. Everything else about Textream (voice-follow highlighting, overlay, settings) keeps working as it does now.

## The deck server (already running, don't change it)
A small HTTP server on the recording Mac, default base URL `http://localhost:8123` (also reachable over Tailscale as `http://cyberyogin:8123`). Source for reference: `/Users/gorkolas/www/podcast/deck/serve.py`, deck data format: `/Users/gorkolas/www/podcast/deck/slides.json`.

- `GET /deck/slides.json` → `{title, episode, slides:[...], timeline:{events:[{key, year, title, ...}], eras:[...]}}`. Each slide has `id`, `key`, `type`, `section`, `script` (the text read on air over that slide; may be empty), and on the timeline slide `segments: [{event, text}]` (one block of text per timeline event).
- `GET /sync/stream` → Server-Sent Events. Each event is `data: <json>`. On connect the server immediately sends the last known position. Messages:
  - `{"type":"goto","i":<0-based slide index>,"tlPos":<timeline event index, optional>,"reveal":..,"scrollY":..,"panX":..,"from":..}` → the show moved. `tlPos` is only meaningful when `slides[i].type == "timeline"`.
  - `{"type":"reload","from":"server"}` → slides.json changed on disk: re-fetch it.
  - `{"type":"video",...}`, `{"type":"vstate",...}` → ignore.
  - lines starting with `:` are keep-alive pings.

## What to show
- Current slide `s = slides[i]`.
- If `s.type == "timeline"` and `s.segments` is non-empty and `tlPos` is present: the event key is `timeline.events[tlPos].key`; show the text of the segment whose `event` equals that key. If no segment matches (some events have no text), keep showing the previous segment's text.
- Otherwise show `s.script`. If it's empty (a slide that plays over the previous paragraph), keep showing the previous slide's text rather than going blank.
- Optionally show a small header with `s.section` and slide number (`i+1` / total), in the app's existing style. Keep it subtle.
- When the text changes, reset the voice-follow position to the start of the new text, exactly as if the user had loaded a new script.

## UI / settings
- A setting (wherever Textream keeps its settings) to turn **Deck Sync** on/off and edit the server URL (default `http://localhost:8123`). Persist both.
- When Deck Sync is on and the server can't be reached, show the last text plus a small unobtrusive "deck offline" indicator, and retry with backoff (1s, 2s, 5s, then every 5s). Never crash, never block the UI thread.
- When Deck Sync is off, Textream behaves exactly like upstream.

## Implementation notes
- Read the code first and follow its architecture and style (SwiftUI/AppKit patterns, how the script model is stored and how the highlighter is reset). Put the new code in its own file(s), e.g. `DeckSync.swift`, with a minimal, clearly marked hook into the existing script model.
- SSE: use `URLSession` with a streaming data task (`bytes(for:)` / `AsyncBytes.lines`), parse `data:` lines, decode JSON with `Codable` (be lenient: unknown fields and missing optional fields must not fail decoding).
- Networking: allow plain HTTP to localhost and the Tailscale host (App Transport Security exception if the app needs one; check the Info.plist / entitlements, and sandbox `com.apple.security.network.client` if the app is sandboxed).
- No new third-party dependencies.

## Constraints
- Xcode is NOT installed yet on this Mac (only Command Line Tools), so a full `xcodebuild` isn't possible. Do what you can to check your work: `swiftc -typecheck` the new file(s) against the macOS SDK where feasible, and keep the Xcode project file consistent (add the new file(s) to the target in `Textream.xcodeproj/project.pbxproj` correctly, or explain exactly what must be added in Xcode).
- You may use `curl http://localhost:8123/deck/slides.json` and `curl -N http://localhost:8123/sync/stream` to see real data, if the server is running.
- Work on a new branch `deck-sync`. Commit with a clear message, author SPANISH FLU <mrflu1918@proton.me> (already configured in this repo). Do not push.
- Don't touch anything outside this repo.

## Deliverable
The `deck-sync` branch with the feature, and a short `DECK-SYNC.md` explaining: how to turn it on, what it shows, the files changed, how it was checked, and anything left to verify once Xcode is installed (build, run, entitlements).
