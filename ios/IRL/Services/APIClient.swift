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

    /// Register a new user
    func register(biometricKeyId: String, displayName: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "publicKey": biometricKeyId, // simplified — using biometricKeyId as public key for now
            "displayNameHash": displayName,
            "biometricKeyId": biometricKeyId,
        ]
        return try await post(path: "/auth/register", body: body)
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

    // MARK: - Profile

    struct ProfileResponse: Codable {
        let id: String
        let encryptedProfile: String?
        let followers: Int
        let following: Int
        let screenLimitSeconds: Int
        let createdAt: String
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

    func pingScreenTime(seconds: Int) async throws {
        let body: [String: Any] = ["seconds": seconds]
        struct PingResponse: Codable {
            let recorded: Bool
        }
        let _: PingResponse = try await post(path: "/screen-time/ping", body: body, authenticated: true)
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
