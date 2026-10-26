//
//  absum_iosApp.swift
//  absum-ios
//
//  Created by cediackermann on 12.10.2026.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class AppDelegate: NSObject, UIApplicationDelegate {}   // for push later; no configure() here

@main
struct absum_iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var viewModel: AuthenticationViewModel
    @State private var auth: AuthService
    @State private var teams: TeamService

    init() {
        FirebaseApp.configure()
        _viewModel = State(initialValue: AuthenticationViewModel())
        _auth = State(initialValue: AuthService())
        _teams = State(initialValue: TeamService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(viewModel)
                .environment(auth)
                .environment(teams)
        }
    }
}
