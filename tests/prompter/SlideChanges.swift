import AppKit
import SwiftUI

@main
struct SlideChanges {
    @MainActor static func main() {
        _ = NSApplication.shared
        UserDefaults.standard.set(true, forKey: "deckSyncEnabled"); UserDefaults.standard.set(388.35, forKey: "textAreaHeight"); UserDefaults.standard.set("pinned", forKey: "overlayMode")
        let content = OverlayContent()
        let rec = SpeechRecognizer()
        let tracker = NotchFrameTracker()
        let W: CGFloat = 600, H: CGFloat = 32 + 388
        let win = NSWindow(contentRect: NSRect(x: -3000, y: 0, width: W, height: H), styleMask: [.borderless], backing: .buffered, defer: false)
        let hv = NSHostingView(rootView: NotchOverlayView(content: content, speechRecognizer: rec, menuBarHeight: 32, frameTracker: tracker).frame(width: W, height: H))
        win.contentView = hv
        win.orderFrontRegardless()
        func pump(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
        func shot(_ name: String) {
            pump(1.0)
            let rep = hv.bitmapImageRepForCachingDisplay(in: hv.bounds)!
            hv.cacheDisplay(in: hv.bounds, to: rep)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/" + name + ".png"))
        }
        // Same sequence as NotchOverlayController.updateContent (minus the mic).
        func setText(_ text: String) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { setText0(text) }
        }
        func setText0(_ text: String) {
            let words = splitTextIntoWords(text)
            content.scriptRevision = UUID()
            rec.recognizedCharCount = 0
            rec.shouldDismiss = false; rec.isListening = true
            rec.lastSpokenText = ""
            content.words = words
            content.paragraphBreakBeforeWordIndices = paragraphBreakWordIndices(in: text)
            content.totalCharCount = words.joined(separator: " ").count
            content.hasNextPage = false
            content.fitTextArea(panelWidth: W)
            tracker.visibleHeight = 32 + content.textAreaHeight
        }
        let texts = try! JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1] + "/texts.json")))
        func quick(_ name: String) {
            pump(0.15)
            let rep = hv.bitmapImageRepForCachingDisplay(in: hv.bounds)!
            hv.cacheDisplay(in: hv.bounds, to: rep)
            try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1] + "/" + name + ".png"))
        }
        rec.isListening = true
        for (i, t) in texts.enumerated() where !t.isEmpty {
            setText(t); print(i + 1, content.fittedTextAreaHeight ?? -1, content.textAreaHeight); quick(String(format: "z%02d-a", i + 1))
            shot(String(format: "z%02d-b", i + 1))
            let total = content.totalCharCount
            for x in stride(from: 0, through: total, by: 25) { rec.recognizedCharCount = x; pump(0.03) }
            rec.recognizedCharCount = total; pump(0.2)
        }
        print("done")
    }
}
