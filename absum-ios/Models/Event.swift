//
//  Event.swift
//  absum-ios
//
//  Created by cediackermann on 08.11.2026.
//

import Foundation
import FirebaseFirestore


struct Event: Codable, Identifiable {
    @DocumentID var id: String?
    var type: EventType
    var title: String
    var startAt: Date
    var endAt: Date
    var meetAt: Date?
    var status: EventStatus
    var reminderAt: Date?
    var lockAt: Date?
    var createdBy: String
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var updatedBy: String
}

enum EventStatus: String, Codable {
    case scheduled, cancelled
}

enum EventType: String, Codable, CaseIterable {
    case training, game, tournament, other
}
