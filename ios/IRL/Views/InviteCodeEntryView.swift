import SwiftUI

struct InviteCodeEntryView: View {
    let initial: String
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isChecking = false
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle
        case valid
        case invalid(String)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Got an invite?")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(IRLColors.primaryText)
                    Text("Paste it here. You'll automatically connect with whoever invited you.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TextField("Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                    .onChange(of: code) { _, newValue in
                        let cleaned = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        if cleaned != newValue { code = cleaned }
                        status = .idle
                    }

                Group {
                    switch status {
                    case .idle:
                        EmptyView()
                    case .valid:
                        Label("Valid code", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(IRLColors.earthGreen)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    case .invalid(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red.opacity(0.85))
                            .font(.system(size: 14, design: .rounded))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    Task { await verify() }
                } label: {
                    HStack {
                        if isChecking { ProgressView().tint(.black) }
                        Text(isChecking ? "Checking…" : "Use this code")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? Color.white : Color.white.opacity(0.3))
                    .clipShape(Capsule())
                }
                .disabled(!canSave || isChecking)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Invite code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
                if !initial.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            onSave("")
                            dismiss()
                        }
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
            .onAppear { code = initial }
        }
    }

    private var canSave: Bool { code.count >= 4 }

    private func verify() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let peek = try await APIClient.shared.peekInvite(code: code)
            if peek.valid {
                status = .valid
                onSave(code)
                try? await Task.sleep(for: .milliseconds(450))
                dismiss()
            } else {
                status = .invalid("This code isn't usable.")
            }
        } catch let APIError.serverError(code, _) where code == 410 {
            status = .invalid("This invite has already been used or expired.")
        } catch let APIError.serverError(code, _) where code == 404 {
            status = .invalid("We don't recognize that code.")
        } catch {
            status = .invalid("Couldn't verify the code. Try again.")
        }
    }
}
