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
            if roster.isLoading && roster.memberships.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                if !staff.isEmpty {
                    Section("Trainer") {
                        ForEach(staff) { member in
                            Text(member.displayName)
                        }
                    }
                }

                if !players.isEmpty {
                    Section("Spieler") {
                        ForEach(players) { member in
                            Text(member.displayName)
                        }
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

    // MARK: - Lists

    private var staff: [Membership] {
        roster.memberships
            .filter { $0.status == .active && $0.roleId == .coach }
            .sorted { $0.displayName < $1.displayName }
    }

    private var players: [Membership] {
        roster.memberships
            .filter { $0.status == .active && $0.roleId == .player }
            .sorted { $0.displayName < $1.displayName }
    }
}
