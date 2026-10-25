//
//  Role.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation

enum Role: String, Codable, CaseIterable {
    case admin
    case coach
    case assistantCoach
    case player
}

extension Role {
    var title: LocalizedStringResource {
        switch self {
        case .admin:          "Admin"
        case .coach:          "Trainer"
        case .assistantCoach: "Co-Trainer"
        case .player:         "Spieler"
        }
    }
}
