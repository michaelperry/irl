import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let senderId: String
    let ciphertext: String
    let createdAt: String
    let readAt: String?
    let myEnvelope: String?

    /// Decrypted plaintext, populated client-side. Not part of server payload.
    var decryptedText: String?
}

struct ConversationSummary: Identifiable, Codable {
    let id: String
    let otherId: String
    let otherDisplayName: String
    let otherEncryptionPublicKey: String?
    let lastMessage: LastMessageStub?
    let unread: Int
    let lastMessageAt: String?
    let createdAt: String

    struct LastMessageStub: Codable {
        let conversationId: String
        let ciphertext: String
        let senderId: String
        let createdAt: String
    }
}
