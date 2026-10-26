//
//  ClubService.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class ClubService {
    private(set) var memberships: [Membership] = []
    private(set) var teams: [String: Team] = [:]
    private(set) var clubs: [String: Club] = [:]
    private(set) var isLoading: Bool = false
    private(set) var uid: String? = nil
    private(set) var errorMessage: String?
    
    private var membershipListener: ListenerRegistration?
    
    func start(uid: String) {
        guard self.uid != uid else { return }
        
        stop()
        
        self.uid = uid
        isLoading = true
        membershipListener = Firestore.firestore()
            .collection("memberships")
            .whereField("uid", isEqualTo: uid)
            .whereField("status", isEqualTo: MembershipStatus.active.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in
                        self?.report(error)
                        self?.isLoading = false
                    }
                    return
                }
                let memberships = snapshot?.documents.compactMap {
                    try? $0.data(as: Membership.self)
                } ?? []

                Task { @MainActor in
                   await self?.handle(memberships:memberships, for:uid)
                }
            }
    }
    
    func stop() {
        membershipListener?.remove()
        membershipListener = nil
        memberships = []
        teams = [:]
        clubs = [:]
        errorMessage = nil
        isLoading = false
        uid = nil
    }
    
    //MARK: - Private
    
    private func report(_ error: Error) {
        #if DEBUG
        print("ClubService:", error)
        #endif
        errorMessage = String(localized: "Teams konnten nicht geladen werden.")
    }
    
    private func handle(memberships: [Membership], for uid: String) async {
        self.memberships = memberships
        
        let teamIds = Set(memberships.compactMap(\.teamId))
        let clubIds = Set(memberships.map(\.clubId))
        let missingTeams = teamIds.subtracting(teams.keys)
        let missingClubs = clubIds.subtracting(clubs.keys)
        
        let db = Firestore.firestore()
        
        for id in missingTeams {
            do {
                let team = try await db.collection("teams").document(id).getDocument(as: Team.self)
                guard self.uid == uid else { return }
                teams[id] = team
            } catch {
                report(error)
            }
        }
        
        for id in missingClubs {
            do {
                let club = try await db.collection("clubs").document(id).getDocument(as: Club.self)
                guard self.uid == uid else { return }
                clubs[id] = club
            } catch {
                report(error)
            }
        }
        
        errorMessage = nil
        self.isLoading = false
    }
}
