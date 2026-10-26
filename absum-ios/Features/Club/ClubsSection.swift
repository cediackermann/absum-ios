//
//  ClubsSection.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct ClubsSection: View {
    @Environment(ClubService.self) private var clubService
    @State private var showClubCreationSheet = false

    var body: some View {
        Section("Clubs") {
            if clubService.isLoading && clubService.clubs.isEmpty {
                ProgressView()
            } else{
                ForEach(sortedClubs) { club in
                    IconRow(
                        title: club.name,
                        subtitle: "Admin",
                        systemImage: "building.2",
                        color: .blue
                    )
                }
                
                Button {
                    showClubCreationSheet = true
                } label: {
                    Label("Club erstellen", systemImage: "plus")
                }
                .sheet(isPresented: $showClubCreationSheet) {
                    CreateClubView()
                }
            }
        }
    }

    private var sortedClubs: [Club] {
        clubService.clubs.values.sorted { $0.name < $1.name }
    }
}

#Preview {
    NavigationStack {
        Form {
            ClubsSection()
        }
    }
    .environment(ClubService())
}
