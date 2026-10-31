//
//  TeamDetailView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct TeamDetailView: View {
    @Environment(ClubService.self) private var clubService
    
    let teamId: String
    
    var body: some View {
        if let team = clubService.teams[teamId] {
            TeamDetailContent(team: team)
                .navigationTitle(team.name)
                .navigationSubtitle(clubService.clubs[team.clubId]?.name ?? "")
        } else {
            ContentUnavailableView("Team nicht gefunden", systemImage: "person.2.slash")
        }
    }
}

private struct TeamDetailContent: View {
    @State private var roster = RosterService()

    let team: Team

    var body: some View {
        List {
            Section("Mitglieder") {
                if roster.isLoading && roster.memberships.isEmpty {
                    ProgressView()
                } else {
                    ForEach(roster.memberships) { member in
                        Text(member.displayName)
                    }
                }
            }
        }
        .task {
            guard let teamId = team.id else { return }
            roster.start(teamId: teamId, clubId: team.clubId)
        }
        .onDisappear {
            roster.stop()
        }
    }
}
