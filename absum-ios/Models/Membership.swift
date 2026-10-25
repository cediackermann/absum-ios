//
//  Membership.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation
import FirebaseFirestore

struct Membership: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var scope: MembershipScope
    var clubId: String
    var teamId: String?
    var roleId: Role
    var status: MembershipStatus
    var displayName: String
    var photoURL: String?
    var accountDeleted: Bool?
    var inviteCode: String?
    @ServerTimestamp var joinedAt: Date?
    var leftAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var updatedBy: String
}

enum MembershipScope: String, Codable {
    case team
    case club
}

enum MembershipStatus: String, Codable {
    case active, pending, left, removed
}
