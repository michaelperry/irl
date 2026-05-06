import SwiftUI

struct ReportSheet: View {
    let targetType: ReportTargetType
    let targetId: String
    /// Reporter's plaintext copy of the content. Sealed to the mod pubkey on submit so triage can read it.
    var plaintextEvidence: String?
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tell us what's wrong")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(IRLColors.primaryText)
                        Text("We review every report. Reports are encrypted to our moderation team — we only read the content you flag.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    VStack(spacing: 8) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Button { selectedReason = reason } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: reason.icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(IRLColors.oceanBlue)
                                        .frame(width: 28)
                                    Text(reason.label)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(IRLColors.primaryText)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(IRLColors.earthGreen)
                                    }
                                }
                                .padding(14)
                                .background(selectedReason == reason ? IRLColors.oceanBlue.opacity(0.12) : .white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add context (optional)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(IRLColors.oceanBlue)
                            .tracking(1)
                        TextField("What happened?", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(IRLColors.primaryText)
                    }
                    .padding(.horizontal, 20)

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Submitting…" : "Submit report")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? IRLColors.oceanBlue : Color.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(IRLColors.deepSpace.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
            .toolbarBackground(IRLColors.deepSpace, for: .navigationBar)
            .alert("Couldn't submit report", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var canSubmit: Bool { selectedReason != nil }

    private func submit() async {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            // Seal the plaintext (if any) to the moderation pubkey so triage can read it.
            var sealedEvidence: String? = nil
            if let plaintext = plaintextEvidence,
               !plaintext.isEmpty,
               let modPub = try? await APIClient.shared.getModeratorPublicKey() {
                let key = CryptoService.freshContentKey()
                let ciphertext = try CryptoService.encryptContent(plaintext, under: key)
                let sealedKey = try CryptoService.sealContentKey(key, forRecipientPubKeyBase64: modPub)
                // Combine envelope and ciphertext for transport.
                let payload: [String: String] = ["sealedKey": sealedKey, "ciphertext": ciphertext]
                if let data = try? JSONSerialization.data(withJSONObject: payload),
                   let str = String(data: data, encoding: .utf8) {
                    sealedEvidence = str
                }
            }

            try await APIClient.shared.report(
                targetType: targetType,
                targetId: targetId,
                reason: reason,
                note: note.isEmpty ? nil : note,
                encryptedEvidence: sealedEvidence
            )
            onDone?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
