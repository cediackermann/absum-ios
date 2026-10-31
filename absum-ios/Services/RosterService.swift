//
//  RosterService.swift
//  absum-ios
//
//  Created by cediackermann on 31.10.2026.
//

import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class RosterService {
    private(set) var memberships: [Membership] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    
    private var teamId: String?
    
    private var membershipsListener: ListenerRegistration?
    
    func start(teamId: String, clubId: String) {
        guard self.teamId != teamId else { return }
        
        stop()
        
        self.teamId = teamId
        isLoading = true
        membershipsListener = Firestore.firestore()
            .collection("memberships")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("clubId", isEqualTo: clubId)
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
                    guard let self, self.teamId == teamId else { return }
                    self.memberships = memberships
                    self.isLoading = false
                }
                    
            }
    }
    
    func stop() {
        membershipsListener?.remove()
        membershipsListener = nil
        memberships = []
    }
    
    //MARK: - Private
    
    private func report(_ error: Error) {
        #if DEBUG
        print("ClubService:", error)
        #endif
        errorMessage = String(localized: "Teams konnten nicht geladen werden.")
    }
    
}
