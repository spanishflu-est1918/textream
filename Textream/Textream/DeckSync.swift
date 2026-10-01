import Foundation
import Combine

struct DeckDocument: Decodable {
    struct Slide: Decodable {
        struct Segment: Decodable { let event: String; let text: String? }
        let type: String?
        let section: String?
        let script: String?
        let segments: [Segment]?
    }
    struct Timeline: Decodable {
        struct Event: Decodable { let key: String }
        let events: [Event]?
    }
    let slides: [Slide]
    let timeline: Timeline?

    /// nil means retain the last text, including on invalid or unvoiced events.
    func text(at index: Int, timelinePosition: Int?) -> String? {
        guard slides.indices.contains(index) else { return nil }
        let slide = slides[index]
        let candidate: String?
        if slide.type == "timeline", let segments = slide.segments, !segments.isEmpty,
           let position = timelinePosition {
            guard let events = timeline?.events, events.indices.contains(position) else { return nil }
            candidate = segments.first { $0.event == events[position].key }?.text
        } else {
            candidate = slide.script
        }
        guard let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

struct DeckMessage: Decodable {
    let type: String
    let i: Int?
    let tlPos: Int?
    let op: String?   // "prompter" messages: "start" / "stop" (the presenter's arm button)

    static func parse(line: String) -> DeckMessage? {
        guard line.hasPrefix("data:") else { return nil }
        return try? JSONDecoder().decode(Self.self, from: Data(line.dropFirst(5).utf8))
    }
}

/// Owns a single cancellable stream. All published state and callbacks are on the UI actor.
@MainActor
final class DeckSync: ObservableObject {
    @Published private(set) var text = ""
    @Published private(set) var status = "Connecting to deck…"
    @Published private(set) var offline = false
    var onTextChange: ((String) -> Void)?
    var onPrompter: ((String) -> Void)?
    private var task: Task<Void, Never>?
    private var session: URLSession?
    private var generation = UUID()
    private var document: DeckDocument?
    private var position: DeckMessage?

    static func baseURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }

    static func retryDelay(_ failures: Int) -> UInt64 {
        [1, 2, 5][min(max(failures, 0), 2)]
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        offline = false
    }

    func start(serverURL: String) {
        stop()
        document = nil
        position = nil
        status = "Connecting to deck…"
        guard let base = Self.baseURL(serverURL) else {
            offline = true
            status = "Invalid deck server URL"
            return
        }
        let token = generation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30 // pings keep a healthy stream alive
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        let session = URLSession(configuration: configuration)
        self.session = session
        task = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                do {
                    let document = try await Self.fetchDeck(base: base, session: session)
                    guard let self, self.generation == token, !Task.isCancelled else { return }
                    self.document = document
                    // Wait for the server's current position on reconnect before changing text.
                    var request = URLRequest(url: base.appendingPathComponent("sync/stream"))
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    let (bytes, response) = try await session.bytes(for: request)
                    try Self.validate(response)
                    for try await line in bytes.lines {
                        guard self.generation == token, !Task.isCancelled else { return }
                        self.offline = false
                        failures = 0
                        guard let message = DeckMessage.parse(line: line) else { continue }
                        switch message.type {
                        case "goto":
                            guard let index = message.i, self.document?.slides.indices.contains(index) == true else { continue }
                            self.position = message
                            self.applyPosition()
                        case "reload":
                            let updated = try await Self.fetchDeck(base: base, session: session)
                            guard self.generation == token, !Task.isCancelled else { return }
                            self.document = updated
                            self.applyPosition()
                        case "prompter":
                            if let op = message.op { self.onPrompter?(op) }
                        default: break
                        }
                    }
                    throw URLError(.networkConnectionLost)
                } catch {
                    guard let self, self.generation == token, !Task.isCancelled else { return }
                    self.offline = true
                    let delay = Self.retryDelay(failures)
                    failures += 1
                    do { try await Task.sleep(nanoseconds: delay * 1_000_000_000) }
                    catch { return }
                }
            }
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private static func fetchDeck(base: URL, session: URLSession) async throws -> DeckDocument {
        let (data, response) = try await session.data(from: base.appendingPathComponent("deck/slides.json"))
        try validate(response)
        return try JSONDecoder().decode(DeckDocument.self, from: data)
    }

    private func applyPosition() {
        guard let document, let position, let index = position.i,
              document.slides.indices.contains(index) else { return }
        let section = document.slides[index].section ?? ""
        status = "\(section.isEmpty ? "Slide" : section) · \(index + 1) / \(document.slides.count)"
        guard let next = document.text(at: index, timelinePosition: position.tlPos), next != text else { return }
        text = next
        onTextChange?(next)
    }
}
