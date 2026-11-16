//
//  EventService.swift
//  absum-ios
//
//  Created by cediackermann on 09.11.2026.
//

import Foundation
import FirebaseFirestore
import Observation

enum EventServiceError: Error {
    case notSignedIn
}

@MainActor
@Observable
final class EventService {
    private(set) var uid: String? = nil
    private(set) var events: [Event] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    
    private var teamId: String?
    
    private var eventListener: ListenerRegistration?
    
    func start(uid: String, teamId: String, clubId: String) {
        self.uid = uid
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
    
    func createEvent(_ build: (String) -> Event) async throws {
        guard let uid else { throw EventServiceError.notSignedIn }

        let event = build(uid)
        let ref = Firestore.firestore().collection("events").document()
        try await ref.setData(Firestore.Encoder().encode(event))
    }
    
    func stop() {
        eventListener?.remove()
        eventListener = nil
        events = []
        uid = nil
    }
    
    //MARK: - Private
    
    private func report(_ error: Error) {
        #if DEBUG
        print("EventService:", error)
        #endif
        errorMessage = String(localized: "Events konnten nicht geladen werden.")
    }
}


extension EventService {
    nonisolated static func message(for error: Error) -> String {
        if let error = error as?EventServiceError {
            switch error {
            case .notSignedIn:
                return String(localized: "Du bist nicht angemeldet.")
            }
        }
        
        let nsError = error as NSError
               if nsError.domain == FirestoreErrorDomain,
                  let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
                   switch code {
                   case .permissionDenied:
                       return String(localized: "Du darfst in diesem Team keine Termine erstellen.")
                   case .unavailable:
                       return String(localized: "Keine Verbindung. Bitte versuche es später nochmals.")
                   default:
                       break
                   }
               }
               return String(localized: "Etwas ist schiefgelaufen. Bitte versuche es nochmals.")
           }
}
