//
//  MainView.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct MainView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel

    var body: some View {
        TabView {
            Tab("Profil", systemImage: "person") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}
