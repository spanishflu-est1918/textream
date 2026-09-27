import SwiftUI

struct DeckOfflineIndicator: View {
    @ObservedObject var deck: DeckSync

    var body: some View {
        if deck.offline {
            Text("deck offline")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                .allowsHitTesting(false)
        }
    }
}

struct DeckSyncPanel: View {
    @ObservedObject var deck: DeckSync
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(deck.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                DeckOfflineIndicator(deck: deck)
            }
            ScrollView {
                Text(deck.text.isEmpty ? "Waiting for a slide with a script…" : deck.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            Button("Start Prompter", action: start)
                .disabled(deck.text.isEmpty)
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300)
    }
}

struct DeckSyncSettingsView: View {
    @Bindable var settings: NotchSettings
    @State private var serverURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Enable Deck Sync", isOn: $settings.deckSyncEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
            Text("Follow the slide or timeline event currently on air. Start the prompter from the main window. Deck Sync takes priority over Director Mode; your open document is preserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Server URL", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .onSubmit { settings.deckServerURL = serverURL }
            Button("Apply URL") { settings.deckServerURL = serverURL }
                .disabled(DeckSync.baseURL(serverURL) == nil)
            Text("Default: http://localhost:8123\nTailscale: http://cyberyogin:8123")
                .font(.caption)
                .foregroundStyle(.secondary)
            DeckOfflineIndicator(deck: TextreamService.shared.deckSync)
            Spacer()
        }
        .padding(16)
        .onAppear { serverURL = settings.deckServerURL }
        .onChange(of: settings.deckServerURL) { _, value in serverURL = value }
    }
}
