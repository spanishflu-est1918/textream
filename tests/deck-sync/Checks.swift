import Foundation

@main
struct Checks {
    @MainActor
    static func main() async throws {
        let source = #"{"slides":[{"script":" Intro "},{"script":" "},{"type":"timeline","script":"Fallback","segments":[{"event":"a","text":"Alpha"},{"event":"c","text":"Charlie"}]},{}],"timeline":{"events":[{"key":"a"},{"key":"b"},{"key":"c"}]},"unknown":true}"#
        let deck = try JSONDecoder().decode(DeckDocument.self, from: Data(source.utf8))
        assert(deck.text(at: 0, timelinePosition: nil) == "Intro")
        assert(deck.text(at: 1, timelinePosition: nil) == nil)
        assert(deck.text(at: 2, timelinePosition: 0) == "Alpha")
        assert(deck.text(at: 2, timelinePosition: 1) == nil)
        assert(deck.text(at: 2, timelinePosition: 2) == "Charlie")
        assert(deck.text(at: 2, timelinePosition: nil) == "Fallback")
        assert(deck.text(at: 2, timelinePosition: -1) == nil)
        assert(deck.text(at: 2, timelinePosition: 99) == nil)
        assert(deck.text(at: -1, timelinePosition: nil) == nil)
        assert(deck.text(at: 99, timelinePosition: nil) == nil)
        assert(deck.text(at: 3, timelinePosition: nil) == nil)
        assert(DeckMessage.parse(line: ": ping") == nil)
        assert(DeckMessage.parse(line: "data: broken") == nil)
        assert(DeckMessage.parse(line: #"data: {"type":"goto","i":0,"extra":true}"#)?.i == 0)
        assert(DeckMessage.parse(line: #"data: {"type":"reload"}"#)?.type == "reload")
        assert(DeckMessage.parse(line: #"data: {"type":"prompter","op":"start"}"#)?.op == "start")
        assert(DeckMessage.parse(line: #"data: {"type":"prompter","op":"clock","t0":1759300000000}"#)?.t0 == 1759300000000)
        assert(DeckSync.baseURL("file:///tmp/deck") == nil)
        assert(DeckSync.baseURL("http://localhost:8123") != nil)
        assert((0...5).map { DeckSync.retryDelay($0) } == [1, 2, 5, 5, 5, 5])
        let client = DeckSync()
        var changes: [String] = []
        client.onTextChange = { changes.append($0) }
        client.start(serverURL: CommandLine.arguments[1])
        // Fixture sends duplicate, empty, timeline, unknown, malformed, reload,
        // then EOF followed by HTTP failures. Verify actual streaming + retries.
        try await Task.sleep(nanoseconds: 5_000_000_000)
        assert(changes == ["Intro", "Alpha", "Revised"], "Unexpected callbacks: \(changes)")
        assert(client.text == "Revised")
        assert(client.offline)
        client.stop()
        let count = changes.count
        try await Task.sleep(nanoseconds: 1_200_000_000)
        assert(changes.count == count && !client.offline)
        print("Deck Sync checks passed (resolution, SSE, reload, retention, EOF, retry, cancellation).")
    }
}
