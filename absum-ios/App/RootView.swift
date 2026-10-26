//
//  RootView.swift
//  absum-ios
//
//  Created by cediackermann on 12.10.2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TeamService.self) private var teams

    var body: some View {
        Group {
            switch auth.state {
            case .checking:
                ProgressView()
            case .unauthenticated:
                AuthenticationView()
            case .authenticated:
                MainView()
            }
        }
        .animation(.default, value: auth.state)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await auth.validateSession() }
            }
        }
        .task(id: auth.uid) {
            if let uid = auth.uid {
                teams.start(uid: uid)
            } else {
                teams.stop()
            }
        }
    }
}
