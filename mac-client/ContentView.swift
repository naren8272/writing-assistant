import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Writing Assistant").font(.headline)
                Spacer()
                Text("⌥⌘R").font(.caption).foregroundStyle(.secondary)
                Button("Quit") { NSApp.terminate(nil) }.controlSize(.small)
            }

            TextEditor(text: $state.input)
                .font(.body)
                .frame(height: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            HStack {
                Button("Rewrite") { state.rewrite() }
                    .keyboardShortcut(.return, modifiers: .command)
                if state.loading { ProgressView().controlSize(.small) }
            }

            if let error = state.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(state.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(suggestion.mode.capitalized).font(.subheadline).bold()
                                Spacer()
                                Button("Copy") { copy(suggestion.text) }.controlSize(.small)
                            }
                            Text(suggestion.text).textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: 380)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
