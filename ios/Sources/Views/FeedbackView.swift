import SwiftUI
import UIKit

/// Capture ideas and issues for the app so they aren't forgotten.
struct FeedbackView: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var kind: FeedbackKind = .idea
    @State private var showShare = false

    private var open: [FeedbackNote] { store.sortedFeedback.filter { !$0.done } }
    private var done: [FeedbackNote] { store.sortedFeedback.filter { $0.done } }

    var body: some View {
        List {
            Section("Add a note") {
                Picker("Type", selection: $kind) {
                    ForEach(FeedbackKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("What's the idea or issue?", text: $text, axis: .vertical)
                    .lineLimit(2...5)

                Button {
                    store.addFeedback(text, kind: kind)
                    text = ""
                } label: {
                    Label("Save note", systemImage: "plus.circle.fill")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !open.isEmpty {
                Section("Open") {
                    ForEach(open) { note in row(note) }
                        .onDelete { delete(open, $0) }
                }
            }

            if !done.isEmpty {
                Section("Resolved") {
                    ForEach(done) { note in row(note) }
                        .onDelete { delete(done, $0) }
                }
            }

            if store.feedback.isEmpty {
                Section {
                    Text("Jot down anything you'd change or any bug you spot. It's saved on your device.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ideas & Issues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(store.feedback.isEmpty)
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(text: store.feedbackExport())
        }
    }

    private func row(_ note: FeedbackNote) -> some View {
        Button {
            withAnimation { store.toggleFeedbackDone(note) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: note.done ? "checkmark.circle.fill" : note.kind.symbol)
                    .foregroundStyle(note.done ? Color.secondary : (note.kind == .issue ? Color(hex: "#FB7185") : Color(hex: "#F59E0B")))
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.text)
                        .foregroundStyle(note.done ? .secondary : .primary)
                        .strikethrough(note.done)
                    Text(note.createdAt.formatted(.dateTime.month().day()))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func delete(_ list: [FeedbackNote], _ offsets: IndexSet) {
        for i in offsets { store.deleteFeedback(list[i]) }
    }
}

/// Minimal UIActivityViewController wrapper for sharing text.
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
