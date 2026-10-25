//
//  Team.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation
import FirebaseFirestore

struct Team: Codable, Identifiable {
    @DocumentID var id: String?
    var clubId: String
    var name: String
    var sport: String?
    var timezone: TimeZone
    var archived: Bool
    var settings: TeamSettings
    @ServerTimestamp var createdAt: Date?
}

struct TeamSettings: Codable, Equatable {
    var reasonVisibility: ReasonVisibility = .staff
    var defaultReminderOffsetMin: Int = 6 * 60
    var defaultLockOffsetMin: Int? = 3 * 60
}

enum ReasonVisibility: String, Codable, CaseIterable, Identifiable {
    case staff
    case team
    var id: Self { self }
}
