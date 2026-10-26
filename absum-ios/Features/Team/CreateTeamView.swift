//
//  CreateTeamView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct CreateTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ClubService.self) private var clubService
    @Environment(AuthService.self) private var auth

    @State private var name = ""
    @State private var clubId: String?
    @State private var sport = ""
    @State private var addMeAsCoach = true

    @State private var isWorking = false
    @State private var showClubCreationSheet = false
    @State private var errorMessage: String?
    
    private var selectedClubName: String? {
        adminClubs.first { $0.id == clubId }?.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("z. B. U20 Männer"))
                    TextField("Sportart", text: $sport, prompt: Text("Optional"))
                }

                Section {
                    LabeledContent("Club") {
                        Menu {
                            Picker("Club", selection: $clubId) {
                                ForEach(adminClubs) { club in
                                    Text(club.name).tag(club.id)
                                }
                            }

                            Divider()

                            Button("Club erstellen", systemImage: "plus") {
                                showClubCreationSheet = true
                            }
                        } label: {
                            Text(selectedClubName ?? "Auswählen")
                        }
                    }

                    Toggle("Ich bin Trainer dieses Teams", isOn: $addMeAsCoach)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Neues Team")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button(role: .confirm) {
                            Task { await create() }
                        }
                        .disabled(!canCreate)
                    }
                }
            }
            .onAppear {
                clubId = clubId ?? adminClubs.first?.id
            }
            .sheet(isPresented: $showClubCreationSheet) {
                CreateClubView()
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    // MARK: - Private

    private var adminClubs: [Club] {
        clubService.memberships
            .filter { $0.scope == .club && $0.roleId == .admin }
            .compactMap { clubService.clubs[$0.clubId] }
            .sorted { $0.name < $1.name }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && clubId != nil
            && auth.profile != nil
            && !isWorking
    }

    private func create() async {
        guard let clubId else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await clubService.createTeam(
                name: name,
                sport: sport,
                in: clubId,
                addMeAsCoach: addMeAsCoach,
                displayName: auth.profile?.displayName ?? "",
                photoURL: auth.profile?.photoURL
            )
            dismiss()
        } catch {
            errorMessage = ClubService.message(for: error)
        }
    }
}
