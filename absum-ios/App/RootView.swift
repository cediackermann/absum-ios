//
//  RootView.swift
//  absum-ios
//
//  Created by cediackermann on 12.10.2026.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    
    var body: some View {
        switch viewModel.authenticationState {
        case .authenticated:
            MainView()
        case .authenticating:
            ProgressView()
        case .unauthenticated:
            AuthenticationView()
        }
    }
}

#Preview {
    RootView()
        .environment(AuthenticationViewModel())
}
