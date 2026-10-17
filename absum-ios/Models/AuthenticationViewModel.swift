//
//  AuthentivationViewModel.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import Foundation
import Combine
import FirebaseAuth
import Observation

enum AuthenticationState {
  case unauthenticated
  case authenticating
  case authenticated
}

enum AuthenticationFlow {
  case login
  case signUp
}

@MainActor
@Observable
final class AuthenticationViewModel {
    var email: String = ""
    var password: String = ""
    
    var flow: AuthenticationFlow = .login
    
    var authenticationState: AuthenticationState = .unauthenticated
    var user: User?
    var errorMessage: String = ""
    var displayName: String = ""
    var isValid: Bool {
        switch flow {
        case .login:
            return !email.isEmpty && !password.isEmpty
        case .signUp:
            return !displayName.isEmpty && !email.isEmpty && password.count >= 10
        }
    }

    init() {
        registerAuthStateHandler()
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    func registerAuthStateHandler(){
        if authStateHandle == nil {
            authStateHandle = Auth.auth().addStateDidChangeListener{ auth, user in
                self.user = user
                self.authenticationState = user == nil ? .unauthenticated : .authenticated
                self.displayName = user?.email ?? "unknown"
            }
        }
    }

    func switchFlow() {
        flow = flow == .login ? .signUp : .login
        errorMessage = ""
      }

      func reset() {
        flow = .login
        email = ""
        password = ""
      }
}

// MARK: - Email and Password Authentication

extension AuthenticationViewModel {
  func signInWithEmailPassword() async -> Bool {
    authenticationState = .authenticating
      do {
          let authResult = try await Auth.auth().signIn(
            withEmail: email,
            password: password
          )
          user = authResult.user
          print("User \(authResult.user.uid) signed in")
          return true
      }
      catch {
          print(error)
          errorMessage = error.localizedDescription
          authenticationState = .unauthenticated
          return false
      }
  }

  func signUpWithEmailPassword() async -> Bool {
      authenticationState = .authenticating
        do {
            let authResult = try await Auth.auth().createUser(
              withEmail: email,
              password: password
            )
            user = authResult.user
            print("User \(authResult.user.uid) signed in")
            return true
        }
        catch {
            print(error)
            errorMessage = error.localizedDescription
            authenticationState = .unauthenticated
            return false
        }
  }

  func signOut() {
      do {
          try Auth.auth().signOut()
      } catch {
          errorMessage = String(localized: "Abmelden fehlgeschlagen.")
      }
  }

  func deleteAccount() async -> Bool {
      do {
          try await user?.delete()
          return true
      }
      catch {
          errorMessage = error.localizedDescription
          return false
      }
  }
}
