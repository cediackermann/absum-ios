//
//  EventRow.swift
//  absum-ios
//
//  Created by cediackermann on 16.11.2026.
//

import SwiftUI

struct EventRow: View {
    let event: Event
    var teamName: String? = nil

    var body: some View {
        IconRow(
            title: event.title,
            subtitle: subtitle,
            systemImage: event.type.systemImage,
            color: event.status == .cancelled ? .gray : event.type.color
        )
    }

    private var subtitle: String {
        var parts: [String] = []

        if event.status == .cancelled {
            parts.append(String(localized: "Abgesagt"))
        }

        parts.append((event.startAt..<event.endAt).formatted(.interval.hour().minute()))

        if let teamName {
            parts.append(teamName)
        }

        return parts.joined(separator: " · ")
    }
}

extension EventType {
    var color: Color {
        switch self {
        case .training: .blue
        case .game: .orange
        case .tournament: .purple
        case .other: .gray
        }
    }
}
