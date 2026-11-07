//
//  TeamDetailView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct TeamDetailView: View {
    @Environment(ClubService.self) private var clubService
    
    @State private  var showInviteSheet = false
    
    let teamId: String
    
    var body: some View {
        if let team = clubService.teams[teamId] {
            TeamDetailContent(team: team)
                .navigationTitle(team.name)
                .navigationSubtitle(clubService.clubs[team.clubId]?.name ?? "")
                .toolbar {
                    if clubService.canInvite(to: team) {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showInviteSheet = true
                            } label: {
                                Image(systemName: "person.badge.plus")
                            }
                            .accessibilityLabel("Teammitglied hinzufügen")
                        }
                    }
                }
                .sheet(isPresented: $showInviteSheet) {
                    InviteView(teamId: teamId, clubId: team.clubId)
                }
        } else {
            ContentUnavailableView("Team nicht gefunden", systemImage: "person.2.slash")
        }
    }
}

private struct TeamDetailContent: View {
    @Environment(ClubService.self) private var clubService
    
    @State private var roster = RosterService()
    @State private var errorMessage: String?
    @State private var busyIds: Set<String> = []

    let team: Team

    var body: some View {
        List {
            if roster.isLoading && roster.memberships.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                if !pendingMembers.isEmpty && clubService
                    .canManageMembers(of: team) {
                    Section("Anfragen") {
                        ForEach(pendingMembers) { member in
                            HStack {
                                Text(member.displayName)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        Task {
                                            await setStatus(.left, for: member)
                                        }
                                    } label: {
                                        Label("Ablehnen", systemImage: "xmark")
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.glass)

                                    Button {
                                        Task { await setStatus(.active, for: member) }
                                    } label: {
                                        Label("Annehmen", systemImage: "checkmark")
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(.glassProminent)
                                }
                                .labelStyle(.iconOnly)
                                .buttonBorderShape(.circle)
                                .controlSize(.large)
                                .disabled(busyIds.contains(member.id ?? ""))
                            }
                        }
                    }
                }
                
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
    
    private var pendingMembers: [Membership] {
        roster.memberships
            .filter { $0.status == .pending }
            .sorted { $0.displayName < $1.displayName }
    }

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
    
    // MARK: - Private
    
    private func setStatus(_ status: MembershipStatus, for member: Membership) async {
        guard let id = member.id else { return }
        busyIds.insert(id)
        errorMessage = nil
        defer { busyIds.remove(id) }

        do {
            try await clubService.setStatus(status, for: id)
        } catch {
            errorMessage = ClubService.message(for: error)
        }
    }
}
