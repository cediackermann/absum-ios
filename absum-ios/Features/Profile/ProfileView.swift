//
//  ProfileView.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ClubService.self) private var clubService
    
    @State private var showDeleteConfirmation = false
    @State private var showClubCreationSheet = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    Text(auth.displayName)
                        .font(.title2.bold())
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            
            Section {
                VStack(alignment: .leading) {
                    ForEach(clubService.teams.sorted(by: { $0.key < $1.key }), id: \.key) { key, team in
                        Text("\(key): \(team.name)")
                    }
                }
                Button {
                    
                } label: {
                    Label("Team erstellen", systemImage: "plus")
                }
            } header: {
                Text("Meine Teams")
            }
            
            ClubsSection()

            Section {
                Button("Abmelden") {
                    do {
                        try auth.signOut()
                        } catch {
                    }
                }
                .frame(maxWidth: .infinity)

                Button("Konto löschen", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Profil")
        .confirmationDialog("Konto endgültig löschen?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Konto löschen", role: .destructive) {
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Dein Konto und deine Daten werden gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
    }
}

#Preview {
    NavigationStack {
    }
}
