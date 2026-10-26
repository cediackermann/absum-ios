//
//  ClubsSection.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import Foundation
import SwiftUI

struct ClubsSection: View {
    @Environment(ClubService.self) private var clubService
    @State private var showClubCreationSheet = false

    var body: some View {
        Section("Clubs") {
            ForEach(sortedClubs) { club in
                IconRow(title: club.name, subtitle: "Admin",
                        systemImage: "", color: .blue)
            }
            Button {
                showClubCreationSheet = true
            } label: {
                Label("Club erstellen", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showClubCreationSheet) {
            CreateClubView()
        }
    }

    private var sortedClubs: [Club] {
        clubService.clubs.values.sorted { $0.name < $1.name }
    }
}
