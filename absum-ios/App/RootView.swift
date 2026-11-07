//
//  RootView.swift
//  absum-ios
//
//  Created by cediackermann on 12.10.2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ClubService.self) private var clubService
    @Environment(\.scenePhase) private var scenePhase

    @State private var pendingJoin: JoinLink?

    var body: some View {
        Group {
            switch auth.state {
            case .checking: ProgressView()
            case .unauthenticated: AuthenticationView()
            case .authenticated: MainView()
            }
        }
        .animation(.default, value: auth.state)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await auth.validateSession() } }
        }
        .task(id: auth.uid) {
            if let uid = auth.uid {
                clubService.start(uid: uid)
            } else {
                clubService.stop()
            }
        }
        .onOpenURL { url in
            pendingJoin = JoinLink(url: url)
        }
        .sheet(item: joinSheetBinding) { link in
            JoinTeamView(initialCode: link.code)
        }
    }

    private var joinSheetBinding: Binding<JoinLink?> {
        Binding(
            get: { auth.state == .authenticated ? pendingJoin : nil },
            set: { pendingJoin = $0 }
        )
    }
}

struct JoinLink: Identifiable {
    let code: String
    var id: String { code }

    init?(url: URL) {
        guard url.scheme == "absum",
              url.host == "join",
              let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?
                  .first(where: { $0.name == "code" })?
                  .value,
              !code.isEmpty
        else { return nil }
        self.code = code
    }
}
