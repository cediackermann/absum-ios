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

extension Membership {
    static func clubDocumentID(clubId: String, uid: String) -> String {
        "c_\(clubId)_\(uid)"
    }
    
    static func teamDocumentID(teamId: String, uid: String) -> String {
        "t_\(teamId)_\(uid)"
    }
    
    static func clubAdmin(uid: String, clubId: String,
                            displayName: String, photoURL: String?) -> Membership {
          Membership(
              id: nil,
              uid: uid,
              scope: .club,
              clubId: clubId,
              teamId: nil,
              roleId: .admin,
              status: .active,
              displayName: displayName,
              photoURL: photoURL,
              accountDeleted: nil,
              inviteCode: nil,
              joinedAt: nil,
              leftAt: nil,
              updatedAt: nil,
              updatedBy: uid
          )
      }
    
    static func coach(uid: String, clubId: String, teamId: String,
                      displayName: String, photoURL: String?) -> Membership {
        Membership(
            id: nil,
            uid: uid,
            scope: .team,
            clubId: clubId,
            teamId: teamId,
            roleId: .coach,
            status: .active,
            displayName: displayName,
            photoURL: photoURL,
            accountDeleted: nil,
            inviteCode: nil,
            joinedAt: nil,
            leftAt: nil,
            updatedAt: nil,
            updatedBy: uid
        )
    }
}
