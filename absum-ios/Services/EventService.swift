//
//  EventService.swift
//  absum-ios
//
//  Created by cediackermann on 09.11.2026.
//

import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class EventService {
    private(set) var events: [Event] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    
    private var teamId: String?
    
    private var eventListener: ListenerRegistration?
    
    func start(teamId: String, clubId: String) {
        guard self.teamId != teamId else { return }
        
        stop()
        
        self.teamId = teamId
        isLoading = true
        eventListener = Firestore.firestore()
            .collection("events")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("clubId", isEqualTo: clubId)
            .whereField("startAt", isGreaterThan: Timestamp(date: Date()))
            .order(by: "startAt")
            .addSnapshotListener { [weak self ] snapshot, error in
                if let error {
                    Task { @MainActor in
                        self?.report(error)
                        self?.isLoading = false
                    }
                    return
                }
                let events = snapshot?.documents.compactMap {
                    try? $0.data(as: Event.self)
                } ?? []
                
                Task { @MainActor in
                    guard let self, self.teamId == teamId else {
                        return
                    }
                    self.events = events
                    self.isLoading = false
                }
            }
        
    }
    
    func stop() {
        eventListener?.remove()
        eventListener = nil
        events = []
    }
    
    //MARK: - Private
    
    private func report(_ error: Error) {
        #if DEBUG
        print("EventService:", error)
        #endif
        errorMessage = String(localized: "Events konnten nicht geladen werden.")
    }
}
