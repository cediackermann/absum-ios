//
//  MainView.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct MainView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(ClubService.self) private var clubService
    @Environment(EventService.self) private var eventService

    var body: some View {
        TabView {
            Tab("Profil", systemImage: "person") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .task(id: Set(clubService.teams.keys)) {
            eventService.sync(teamIds: Set(clubService.teams.keys))
        }
    }
}
