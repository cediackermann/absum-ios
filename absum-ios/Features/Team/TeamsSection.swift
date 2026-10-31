//
//  TeamsSection.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct TeamsSection: View {
    @Environment(ClubService.self) private var clubService
    @State private var showTeamreationSheet = false

    var body: some View {
        Section("Clubs") {
            if clubService.isLoading && clubService.teams.isEmpty {
                ProgressView()
            } else{
                ForEach(sortedTeams) { team in
                    if let teamId = team.id {
                        NavigationLink(value: TeamRoute(teamId: teamId)) {
                            IconRow(
                                title: team.name,
                                subtitle: "Admin",
                                systemImage: "building.2",
                                color: .blue
                            )
                        }
                    }
                }
                
                Button {
                    showTeamreationSheet = true
                } label: {
                    Label("Team erstellen", systemImage: "plus")
                }
                .sheet(isPresented: $showTeamreationSheet) {
                    CreateTeamView()
                }
            }
        }
    }

    private var sortedTeams: [Team] {
        clubService.teams.values.sorted { $0.name < $1.name }
    }
}

#Preview {
    NavigationStack {
        Form {
            TeamsSection()
        }
    }
    .environment(ClubService())
}
