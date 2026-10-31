//
//  Invite.swift
//  absum-ios
//
//  Created by cediackermann on 31.10.2026.
//

import Foundation
import FirebaseFirestore

struct Invite: Codable, Identifiable {
    @DocumentID var id: String?
    var teamId: String
    var clubId: String
    var requiresApproval: Bool
    var revoked: Bool
    var expiresAt: Date
    var createdBy: String
    @ServerTimestamp var createdAt: Date?
}

extension Invite {
    var code: String {
        id ?? ""
    }
    var isUsable: Bool {
        !revoked && expiresAt > Date.now
    }
    
    static nonisolated let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    static nonisolated func generateCode() -> String {
        
        let eightRandChars = (0..<8).compactMap { _ in alphabet.randomElement() }
        return String(eightRandChars)
    }
}
