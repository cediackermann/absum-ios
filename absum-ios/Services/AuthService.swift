//
//  AuthService.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import FirebaseAuth
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class AuthService {
    private(set) var user: FirebaseAuth.User?
    private(set) var profile: AppUser?
    private(set) var state: AuthenticationState = .checking
    
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var profileListener: ListenerRegistration?
    
    init() {
        authHandle = Auth.auth().addStateDidChangeListener{ [weak self] _, user in
            Task { @MainActor in self?.update(user: user) }
        }
    }
    
    private func update(user: FirebaseAuth.User?) {
        self.user = user
        state = user == nil ? .unauthenticated : .authenticated
        profileListener?.remove()
        profileListener = nil
        profile = nil
        guard let uid = user?.uid else { return }
        profileListener = Firestore
            .firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener {
                [weak self] snapshot, _ in
                let profile = try? snapshot?.data(as: AppUser.self)
                Task { @MainActor in self?.profile = profile }
            }
        
    }
    
    func validateSession() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.reload()
        } catch let error as NSError where error.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: error.code) {
            case .userNotFound, .userDisabled, .userTokenExpired, .invalidUserToken:
                try? signOut()
            default:
                break
            }
        } catch {
        }
    }
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signUp(name: String, email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(
            withEmail: email,
            password: password
        )
        try Firestore.firestore().collection("users").document(result.user.uid)
            .setData(
                from: AppUser(displayName: name, locale: AppLocale.current)
            )
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func deleteAccount() throws {
        
    }
    
}

// MARK: - Quick access

extension AuthService {
    var uid: String? { user?.uid }
    var email: String { user?.email ?? "" }

    var displayName: String { profile?.displayName ?? "" }
    var photoURL: URL? { profile?.photoURL.flatMap(URL.init(string:)) }
    var locale: AppLocale { profile?.locale ?? .current }

    /// True once the profile document has loaded, e.g. to show a placeholder until then.
    var isProfileLoaded: Bool { profile != nil }
}

enum AuthenticationState {
  case unauthenticated
  case checking
  case authenticated
}
