import Foundation

struct Invite: Identifiable, Codable {
    let id: String
    let inviterId: String
    let code: String
    let redeemerId: String?
    let createdAt: String
    let redeemedAt: String?
    let expiresAt: String

    var isRedeemed: Bool { redeemedAt != nil }
}
