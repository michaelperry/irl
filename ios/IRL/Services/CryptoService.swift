import Foundation
import CryptoKit

/// E2E crypto for IRL.
///
/// Identity keypair: X25519 (Curve25519). Private key persisted in Keychain (kSecAttrAccessibleAfterFirstUnlock).
/// Content key: 32-byte SymmetricKey, encrypted-to-recipients via ECDH + ChaCha20-Poly1305.
///
/// Wire format for a sealed key (base64):
///   [32 bytes ephemeral X25519 pubkey] || [12 bytes nonce] || [16+ bytes ciphertext+tag]
///
/// Threat model notes:
/// - Server never sees plaintext content or content keys.
/// - Recipient list is visible to the server (it routes envelopes), but envelope contents aren't.
/// - Forward secrecy is partial — a long-lived identity key compromise lets past traffic be read.
///   Acceptable for v1; can be hardened with double-ratchet later.
enum CryptoService {

    enum CryptoError: Error, LocalizedError {
        case keypairUnavailable
        case malformedSealedKey
        case decryptFailed
        case invalidPublicKey

        var errorDescription: String? {
            switch self {
            case .keypairUnavailable: return "Encryption keypair is unavailable"
            case .malformedSealedKey: return "Sealed key is malformed"
            case .decryptFailed: return "Couldn't decrypt content"
            case .invalidPublicKey: return "Invalid recipient public key"
            }
        }
    }

    // MARK: - Identity keypair

    /// Returns the device's persistent X25519 keypair, generating one on first call.
    static func loadOrGenerateKeypair() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let raw = KeychainService.loadData(key: KeychainService.encryptionPrivateKey),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) {
            return key
        }
        let newKey = Curve25519.KeyAgreement.PrivateKey()
        KeychainService.saveData(key: KeychainService.encryptionPrivateKey, value: newKey.rawRepresentation)
        return newKey
    }

    /// Base64 X25519 public key suitable for sending to the server.
    static func currentPublicKeyBase64() throws -> String {
        let key = try loadOrGenerateKeypair()
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    // MARK: - Content key

    static func freshContentKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // MARK: - Symmetric encrypt / decrypt

    /// Encrypts plaintext under a content key. Returns combined ciphertext (nonce || ct || tag), base64.
    static func encryptContent(_ plaintext: String, under key: SymmetricKey) throws -> String {
        let data = Data(plaintext.utf8)
        let sealed = try ChaChaPoly.seal(data, using: key)
        return sealed.combined.base64EncodedString()
    }

    static func decryptContent(_ base64: String, under key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: base64) else { throw CryptoError.malformedSealedKey }
        let box = try ChaChaPoly.SealedBox(combined: data)
        let plain = try ChaChaPoly.open(box, using: key)
        return String(data: plain, encoding: .utf8) ?? ""
    }

    // MARK: - Sealed key envelopes

    /// Seal a content key for a recipient. Returns base64 envelope.
    static func sealContentKey(_ contentKey: SymmetricKey, forRecipientPubKeyBase64 recipientPubKeyB64: String) throws -> String {
        guard let recipientRaw = Data(base64Encoded: recipientPubKeyB64) else {
            throw CryptoError.invalidPublicKey
        }
        let recipientPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientRaw)

        // Ephemeral keypair for this envelope (forward-secrecy-ish)
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipientPub)
        let kek = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("irl.envelope.v1".utf8),
            outputByteCount: 32
        )

        let keyBytes = contentKey.withUnsafeBytes { Data($0) }
        let sealed = try ChaChaPoly.seal(keyBytes, using: kek)

        var out = Data()
        out.append(ephemeral.publicKey.rawRepresentation)   // 32 bytes
        out.append(sealed.combined)                          // nonce(12) || ct || tag(16)
        return out.base64EncodedString()
    }

    /// Open a sealed key envelope using our long-term private key.
    static func openSealedKey(_ envelopeBase64: String) throws -> SymmetricKey {
        guard let env = Data(base64Encoded: envelopeBase64), env.count > 32 else {
            throw CryptoError.malformedSealedKey
        }
        let ephemeralPubRaw = env.prefix(32)
        let combined = env.suffix(env.count - 32)

        let ephemeralPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPubRaw)
        let myPriv = try loadOrGenerateKeypair()
        let shared = try myPriv.sharedSecretFromKeyAgreement(with: ephemeralPub)
        let kek = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("irl.envelope.v1".utf8),
            outputByteCount: 32
        )

        let box = try ChaChaPoly.SealedBox(combined: combined)
        let raw = try ChaChaPoly.open(box, using: kek)
        return SymmetricKey(data: raw)
    }
}
