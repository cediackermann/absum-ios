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
    var teamId: String
    var clubId: String
    var type: EventType
    var title: String
    var startAt: Date
    var endAt: Date
    var meetAt: Date?
    var location: EventLocation?
    var notes: String?
    var status: EventStatus
    var reminderAt: Date?
    var lockAt: Date?
    var remindedAt: Date?
    var seriesId: String?
    var isException: Bool?
    var createdBy: String
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    var updatedBy: String
}

struct EventLocation: Codable, Equatable {
    var name: String
    var address: String?
}

enum EventStatus: String, Codable {
    case scheduled, cancelled
}

enum EventType: String, Codable, CaseIterable, Identifiable {
    case training, game, tournament, other

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .training: "Training"
        case .game: "Spiel"
        case .tournament: "Turnier"
        case .other: "Anderes"
        }
    }

    var systemImage: String {
        switch self {
        case .training: "figure.run"
        case .game: "sportscourt"
        case .tournament: "trophy"
        case .other: "calendar"
        }
    }
}
