//
//  AuthentivationViewModel.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import Foundation
import Observation

enum AuthenticationFlow {
  case login
  case signUp
}

@MainActor
@Observable
final class AuthenticationViewModel {
    var email: String = ""
    var password: String = ""
    var firstName: String = ""
    var lastName: String = ""
    
    private(set) var isWorking = false
    var errorMessage: String?
    
    var displayName: String {
        "\(firstName.trimmed) \(lastName.trimmed)"
    }
    
    var flow: AuthenticationFlow = .login
    
    var isValid: Bool {
        switch flow {
        case .login:
            return !email.isEmpty && !password.isEmpty
        case .signUp:
            return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && password.count >= 10
        }
    }

    func switchFlow() {
        flow = flow == .login ? .signUp : .login
        password = ""
        errorMessage = ""
      }
    
    func submit(using auth: AuthService) async {
        guard isValid, !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        
        do {
            switch flow {
            case .login:
                try await auth
                    .signIn(email: email.trimmed, password: password)
            case .signUp:
                try await auth
                    .signUp(
                        name: displayName,
                        email: email.trimmed,
                        password: password
                    )
            }
            reset()
        } catch {
            password = "" 
            errorMessage = error.localizedDescription
        }
        
    }
    
    private func reset() {
        firstName = ""
        lastName = ""
        email = ""
        password = ""
        errorMessage = nil
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
