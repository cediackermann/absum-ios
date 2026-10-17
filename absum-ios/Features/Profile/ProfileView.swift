//
//  ProfileView.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    Text(viewModel.displayName)
                        .font(.title2.bold())
                    Text(viewModel.email)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            Section {
                Button("Abmelden") {
                    viewModel.signOut()
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
                Task { await viewModel.deleteAccount() }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Dein Konto und deine Daten werden gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AuthenticationViewModel())
    }
}
