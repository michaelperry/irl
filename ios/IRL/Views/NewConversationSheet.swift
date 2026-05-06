import SwiftUI

struct NewConversationSheet: View {
    var onPick: (APIClient.SearchUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [APIClient.SearchUser] = []
    @State private var inFlight = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchField
                resultsList
                Spacer()
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .alert("Couldn't search", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.4))
            TextField("Find a friend by name", text: $query)
                .foregroundStyle(IRLColors.primaryText)
                .autocorrectionDisabled()
                .onChange(of: query) { _, q in trigger(q) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var resultsList: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            VStack(spacing: 6) {
                Image(systemName: "bubble.left").font(.system(size: 28)).foregroundStyle(IRLColors.oceanBlue.opacity(0.4))
                Text("Search by name")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(IRLColors.primaryText)
                Text("DMs are mutual-friends only — they'll need to be your friend, and you theirs.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 24)
        } else if inFlight && results.isEmpty {
            ProgressView().tint(.white).padding(.top, 24)
        } else if results.isEmpty {
            Text("No matches")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(results) { user in
                        Button {
                            onPick(user)
                        } label: {
                            HStack(spacing: 12) {
                                EarthView(autoRotate: false)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(IRLColors.earthGradient, lineWidth: 1.5))
                                Text(user.displayName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(IRLColors.primaryText)
                                Spacer()
                                Image(systemName: "paperplane.fill")
                                    .foregroundStyle(IRLColors.oceanBlue)
                            }
                            .padding(12)
                            .background(.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private func trigger(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            inFlight = false
            return
        }
        inFlight = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            do {
                let users = try await APIClient.shared.searchUsers(query: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    results = users
                    inFlight = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    inFlight = false
                }
            }
        }
    }
}
