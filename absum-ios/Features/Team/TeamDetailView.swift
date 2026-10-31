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
    let team: Team
    
    var body: some View {
        List {
            
        }
    }
}
