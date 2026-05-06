import Foundation
import UIKit

/// Networking layer for IRL API
final class APIClient {

    static let shared = APIClient()

    private let baseURL = "https://api-kappa-ochre-89.vercel.app/api"

    private init() {}

    // MARK: - Auth

    struct AuthResponse: Codable {
        let user: AuthUser?
        let userId: String?
        let token: String
        let screenLimitSeconds: Int?
    }

    struct AuthUser: Codable {
        let id: String
        let createdAt: String
    }

    /// Register a new user. Optional `inviteCode` redeems an existing invite,
    /// auto-mutual-follows the inviter, and rewards them with a bonus slot.
    func register(biometricKeyId: String, displayName: String, encryptionPublicKey: String?, inviteCode: String? = nil) async throws -> AuthResponse {
        var body: [String: Any] = [
            "publicKey": biometricKeyId, // simplified — using biometricKeyId as attestation key for now
            "displayNameHash": displayName,
            "biometricKeyId": biometricKeyId,
        ]
        if let encryptionPublicKey { body["encryptionPublicKey"] = encryptionPublicKey }
        if let inviteCode = inviteCode?.trimmingCharacters(in: .whitespaces).uppercased(),
           !inviteCode.isEmpty {
            body["inviteCode"] = inviteCode
        }
        return try await post(path: "/auth/register", body: body)
    }

    struct InvitePeek: Codable {
        let valid: Bool
        let inviterId: String
    }

    /// Verify an invite code is valid and returns the inviter's ID (used to show "invited by ..." in onboarding).
    func peekInvite(code: String) async throws -> InvitePeek {
        return try await get(path: "/auth/invite/\(code.uppercased())")
    }

    /// Upload (or rotate) the device's X25519 encryption public key.
    func uploadEncryptionPublicKey(_ pubKeyBase64: String) async throws {
        struct R: Codable { let updated: Bool }
        let _: R = try await post(path: "/auth/encryption-key", body: ["encryptionPublicKey": pubKeyBase64], authenticated: true)
    }

    /// Login with existing biometric key
    func login(biometricKeyId: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "biometricKeyId": biometricKeyId,
            "signedChallenge": "biometric-verified", // simplified for now
        ]
        return try await post(path: "/auth/login", body: body)
    }

    // MARK: - Posts

    struct ServerPost: Codable {
        let id: String
        let userId: String
        let encryptedContent: String?
        let encryptedMediaUrl: String?
        let encryptedMediaKey: String?
        let createdAt: String
    }

    struct FeedResponse: Codable {
        let posts: [ServerPost]
        let hasMore: Bool
        let nextCursor: String?
    }

    /// Create a post on the server
    func createPost(content: String?, mediaBase64: String?, mediaKey: String?) async throws -> ServerPost {
        var body: [String: Any] = [:]
        if let content { body["encryptedContent"] = content }
        if let mediaBase64 { body["encryptedMediaUrl"] = mediaBase64 }
        if let mediaKey { body["encryptedMediaKey"] = mediaKey }

        struct CreateResponse: Codable {
            let post: ServerPost
        }
        let response: CreateResponse = try await post(path: "/posts", body: body, authenticated: true)
        return response.post
    }

    /// Get feed
    func getFeed(limit: Int = 20) async throws -> FeedResponse {
        return try await get(path: "/posts/feed?limit=\(limit)", authenticated: true)
    }

    /// Delete a post on the server (author only). 404 if it isn't yours / doesn't exist.
    func deletePost(serverId: String) async throws {
        struct R: Codable { let deleted: Bool }
        let _: R = try await delete(path: "/posts/\(serverId)", authenticated: true)
    }

    // MARK: - Profile

    struct ProfileResponse: Codable {
        let id: String
        let encryptedProfile: String?
        let followers: Int
        let following: Int
        let friendLimit: Int?
        let friendSlotsRemaining: Int?
        let bonusSlotsUnlocked: Int?
        let bonusSlotsMax: Int?
        let screenLimitSeconds: Int
        let createdAt: String
    }

    struct SearchUser: Codable, Identifiable {
        let id: String
        let displayName: String
        let encryptionPublicKey: String?
        let isFollowing: Bool
    }

    struct SearchResponse: Codable {
        let users: [SearchUser]
    }

    /// Narrow display-name prefix search. Returns up to 20 users; excludes self + blocked.
    func searchUsers(query: String) async throws -> [SearchUser] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let r: SearchResponse = try await get(path: "/profile/search?q=\(encoded)", authenticated: true)
        return r.users
    }

    /// Follow a user. Returns the (potentially updated) friend limit.
    /// Throws an APIError.serverError(409, ...) if the friend cap is reached.
    func followUser(_ userId: String, encryptedSharedKey: String? = nil) async throws {
        var body: [String: Any] = [:]
        body["encryptedSharedKey"] = encryptedSharedKey ?? NSNull()
        struct R: Codable { let followed: Bool; let friendLimit: Int? }
        let _: R = try await post(path: "/profile/follow/\(userId)", body: body, authenticated: true)
    }

    func unfollowUser(_ userId: String) async throws {
        struct R: Codable { let unfollowed: Bool }
        let _: R = try await delete(path: "/profile/follow/\(userId)", authenticated: true)
    }

    func getProfile() async throws -> ProfileResponse {
        return try await get(path: "/profile/me", authenticated: true)
    }

    func updateProfile(encryptedProfile: String?, screenLimit: Int?) async throws {
        var body: [String: Any] = [:]
        if let encryptedProfile { body["encryptedProfile"] = encryptedProfile }
        if let screenLimit { body["dailyScreenLimitSeconds"] = screenLimit }

        struct UpdateResponse: Codable {
            let user: ProfileResponse
        }
        let _: UpdateResponse = try await put(path: "/profile/me", body: body, authenticated: true)
    }

    // MARK: - Screen Time

    struct ScreenTimeResponse: Codable {
        let date: String
        let usedSeconds: Int
        let limitSeconds: Int
        let remainingSeconds: Int
        let limitReached: Bool
    }

    func getScreenTime() async throws -> ScreenTimeResponse {
        return try await get(path: "/screen-time", authenticated: true)
    }

    // MARK: - Invites

    struct InvitesResponse: Codable {
        let invites: [Invite]
    }

    /// Mint up to 5 invite codes (re-uses any unredeemed live ones, idempotent if you already have them).
    func mintInvites(count: Int = 5) async throws -> [Invite] {
        let r: InvitesResponse = try await post(path: "/invites", body: ["count": count], authenticated: true)
        return r.invites
    }

    func listMyInvites() async throws -> [Invite] {
        let r: InvitesResponse = try await get(path: "/invites/me", authenticated: true)
        return r.invites
    }

    // MARK: - Activity

    struct ActivityFeedResponse: Codable {
        let activities: [Activity]
        let hasMore: Bool
        let nextCursor: String?
    }

    func getActivity(before: String? = nil, limit: Int = 30) async throws -> ActivityFeedResponse {
        var path = "/activity?limit=\(limit)"
        if let before, let encoded = before.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&before=\(encoded)"
        }
        return try await get(path: path, authenticated: true)
    }

    func unreadActivityCount() async throws -> Int {
        struct R: Codable { let unread: Int }
        let r: R = try await get(path: "/activity/unread-count", authenticated: true)
        return r.unread
    }

    func markActivityRead() async throws {
        struct R: Codable { let marked: Bool }
        let _: R = try await post(path: "/activity/mark-read", body: [:], authenticated: true)
    }

    // MARK: - Messages (DMs)

    struct ConversationsResponse: Codable {
        let conversations: [ConversationSummary]
    }

    struct ConversationDetailResponse: Codable {
        struct Convo: Codable {
            let id: String
            let otherId: String
        }
        let conversation: Convo
        let messages: [Message]
        let hasMore: Bool
        let nextCursor: String?
    }

    func listConversations() async throws -> [ConversationSummary] {
        let r: ConversationsResponse = try await get(path: "/messages", authenticated: true)
        return r.conversations
    }

    func unreadMessageCount() async throws -> Int {
        struct R: Codable { let unread: Int }
        let r: R = try await get(path: "/messages/unread-count", authenticated: true)
        return r.unread
    }

    func getConversation(withUserId otherId: String, before: String? = nil, limit: Int = 50) async throws -> ConversationDetailResponse {
        var path = "/messages/with/\(otherId)?limit=\(limit)"
        if let before, let encoded = before.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&before=\(encoded)"
        }
        return try await get(path: path, authenticated: true)
    }

    func sendMessage(toUserId otherId: String, ciphertext: String, envelopes: [(recipientId: String, sealedKey: String)]) async throws -> Message {
        var body: [String: Any] = ["ciphertext": ciphertext]
        if !envelopes.isEmpty {
            body["envelopes"] = envelopes.map { ["recipientId": $0.recipientId, "sealedKey": $0.sealedKey] }
        }
        struct R: Codable { let message: Message }
        let r: R = try await post(path: "/messages/with/\(otherId)", body: body, authenticated: true)
        return r.message
    }

    func markConversationRead(conversationId: String) async throws {
        struct R: Codable { let marked: Bool }
        let _: R = try await post(path: "/messages/\(conversationId)/mark-read", body: [:], authenticated: true)
    }

    // MARK: - Stories

    struct StoriesResponse: Codable {
        let groups: [StoryGroup]
    }

    func getStoryGroups() async throws -> [StoryGroup] {
        let r: StoriesResponse = try await get(path: "/stories", authenticated: true)
        return r.groups
    }

    func getStoryAudience() async throws -> [AudienceRecipient] {
        let r: AudienceResponse = try await get(path: "/stories/audience", authenticated: true)
        return r.recipients
    }

    struct CreatedStoryResponse: Codable {
        let story: Story
    }

    func createStory(
        encryptedContent: String? = nil,
        encryptedMediaUrl: String? = nil,
        encryptedMediaKey: String? = nil,
        mediaType: String = "photo",
        trustLevel: String = "verified",
        envelopes: [(recipientId: String, sealedKey: String)] = []
    ) async throws -> Story {
        var body: [String: Any] = ["trustLevel": trustLevel, "mediaType": mediaType]
        if let encryptedContent { body["encryptedContent"] = encryptedContent }
        if let encryptedMediaUrl { body["encryptedMediaUrl"] = encryptedMediaUrl }
        if let encryptedMediaKey { body["encryptedMediaKey"] = encryptedMediaKey }
        if !envelopes.isEmpty {
            body["envelopes"] = envelopes.map { ["recipientId": $0.recipientId, "sealedKey": $0.sealedKey] }
        }
        let r: CreatedStoryResponse = try await post(path: "/stories", body: body, authenticated: true)
        return r.story
    }

    func markStoryViewed(_ storyId: String) async throws {
        struct R: Codable { let viewed: Bool }
        let _: R = try await post(path: "/stories/\(storyId)/view", body: [:], authenticated: true)
    }

    func deleteStory(_ storyId: String) async throws {
        struct R: Codable { let deleted: Bool }
        let _: R = try await delete(path: "/stories/\(storyId)", authenticated: true)
    }

    func registerAPNsToken(token: String, deviceId: String, environment: String) async throws {
        struct R: Codable { let registered: Bool }
        let _: R = try await post(
            path: "/profile/apns-tokens",
            body: ["token": token, "deviceId": deviceId, "environment": environment],
            authenticated: true
        )
    }

    func pingScreenTime(seconds: Int) async throws {
        let body: [String: Any] = ["seconds": seconds]
        struct PingResponse: Codable {
            let recorded: Bool
        }
        let _: PingResponse = try await post(path: "/screen-time/ping", body: body, authenticated: true)
    }

    // MARK: - Reactions

    func setReaction(postId: String, kind: ReactionKind) async throws {
        struct R: Codable { let kind: String }
        let _: R = try await put(path: "/reactions/\(postId)", body: ["kind": kind.rawValue], authenticated: true)
    }

    func clearReaction(postId: String) async throws {
        struct R: Codable { let removed: Bool }
        let _: R = try await delete(path: "/reactions/\(postId)", authenticated: true)
    }

    func setCommentReaction(commentId: String, kind: ReactionKind) async throws {
        struct R: Codable { let kind: String }
        let _: R = try await put(path: "/reactions/comment/\(commentId)", body: ["kind": kind.rawValue], authenticated: true)
    }

    func clearCommentReaction(commentId: String) async throws {
        struct R: Codable { let removed: Bool }
        let _: R = try await delete(path: "/reactions/comment/\(commentId)", authenticated: true)
    }

    func getReactions(postId: String) async throws -> ReactionSummary {
        return try await get(path: "/reactions/\(postId)", authenticated: true)
    }

    // MARK: - Comments

    struct CommentsResponse: Codable {
        let comments: [Comment]
    }

    struct AudienceRecipient: Codable {
        let id: String
        let encryptionPublicKey: String?
    }

    struct AudienceResponse: Codable {
        let recipients: [AudienceRecipient]
    }

    func getPostAudience(postId: String) async throws -> [AudienceRecipient] {
        let r: AudienceResponse = try await get(path: "/posts/\(postId)/audience", authenticated: true)
        return r.recipients
    }

    func createComment(
        postId: String,
        encryptedContent: String,
        parentCommentId: String? = nil,
        envelopes: [(recipientId: String, sealedKey: String)] = []
    ) async throws -> Comment {
        var body: [String: Any] = ["encryptedContent": encryptedContent]
        if let parentCommentId { body["parentCommentId"] = parentCommentId }
        if !envelopes.isEmpty {
            body["envelopes"] = envelopes.map { ["recipientId": $0.recipientId, "sealedKey": $0.sealedKey] }
        }
        struct R: Codable { let comment: Comment }
        let r: R = try await post(path: "/comments/posts/\(postId)", body: body, authenticated: true)
        return r.comment
    }

    func getComments(postId: String) async throws -> [Comment] {
        let r: CommentsResponse = try await get(path: "/comments/posts/\(postId)", authenticated: true)
        return r.comments
    }

    func deleteComment(id: String) async throws {
        struct R: Codable { let deleted: Bool }
        let _: R = try await delete(path: "/comments/\(id)", authenticated: true)
    }

    // MARK: - Safety

    func blockUser(_ userId: String) async throws {
        struct R: Codable { let blocked: Bool }
        let _: R = try await post(path: "/safety/blocks/\(userId)", body: [:], authenticated: true)
    }

    func unblockUser(_ userId: String) async throws {
        struct R: Codable { let unblocked: Bool }
        let _: R = try await delete(path: "/safety/blocks/\(userId)", authenticated: true)
    }

    struct BlockEntry: Codable {
        let blockedId: String
        let createdAt: String
    }

    struct BlocksResponse: Codable {
        let blocks: [BlockEntry]
    }

    func listBlocks() async throws -> [BlockEntry] {
        let r: BlocksResponse = try await get(path: "/safety/blocks", authenticated: true)
        return r.blocks
    }

    func muteUser(_ userId: String, durationSeconds: Int? = nil) async throws {
        var body: [String: Any] = [:]
        if let durationSeconds { body["durationSeconds"] = durationSeconds }
        struct R: Codable { let muted: Bool }
        let _: R = try await post(path: "/safety/mutes/\(userId)", body: body, authenticated: true)
    }

    func unmuteUser(_ userId: String) async throws {
        struct R: Codable { let unmuted: Bool }
        let _: R = try await delete(path: "/safety/mutes/\(userId)", authenticated: true)
    }

    struct ModPubkeyResponse: Codable { let publicKey: String }

    func getModeratorPublicKey() async throws -> String {
        let r: ModPubkeyResponse = try await get(path: "/safety/mod-pubkey", authenticated: true)
        return r.publicKey
    }

    func report(targetType: ReportTargetType, targetId: String, reason: ReportReason, note: String? = nil, encryptedEvidence: String? = nil) async throws {
        var body: [String: Any] = [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "reason": reason.rawValue,
        ]
        if let note { body["note"] = note }
        if let encryptedEvidence { body["encryptedEvidence"] = encryptedEvidence }
        struct R: Codable {
            struct Inner: Codable { let id: String }
            let report: Inner
        }
        let _: R = try await post(path: "/safety/reports", body: body, authenticated: true)
    }

    // MARK: - Generic Request Helpers

    private func get<T: Codable>(path: String, authenticated: Bool = false) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "GET"
        if authenticated { addAuth(to: &request) }
        return try await execute(request)
    }

    private func post<T: Codable>(path: String, body: [String: Any], authenticated: Bool = false) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if authenticated { addAuth(to: &request) }
        return try await execute(request)
    }

    private func put<T: Codable>(path: String, body: [String: Any], authenticated: Bool = false) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        if authenticated { addAuth(to: &request) }
        return try await execute(request)
    }

    private func delete<T: Codable>(path: String, authenticated: Bool = false) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "DELETE"
        if authenticated { addAuth(to: &request) }
        return try await execute(request)
    }

    private func addAuth(to request: inout URLRequest) {
        if let token = KeychainService.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute<T: Codable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[IRL API] Error \(httpResponse.statusCode): \(errorBody)")
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[IRL API] Decode error: \(error)")
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let err): return "Data error: \(err.localizedDescription)"
        }
    }
}
