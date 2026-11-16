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
    private(set) var uid: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var eventsByTeam: [String: [Event]] = [:]
    private var listeners: [String: ListenerRegistration] = [:]

    var events: [Event] {
        eventsByTeam.values.flatMap { $0 }.sorted { $0.startAt < $1.startAt }
    }

    func events(for teamId: String) -> [Event] {
        eventsByTeam[teamId] ?? []
    }

    // MARK: - Lifecycle

    func start(uid: String) {
        guard self.uid != uid else { return }
        stop()
        self.uid = uid
    }

    func stop() {
        listeners.values.forEach { $0.remove() }
        listeners = [:]
        eventsByTeam = [:]
        isLoading = false
        errorMessage = nil
        uid = nil
    }

    func sync(teamIds: Set<String>) {
        guard uid != nil else { return }

        for id in listeners.keys where !teamIds.contains(id) {
            listeners[id]?.remove()
            listeners[id] = nil
            eventsByTeam[id] = nil
        }

        let newTeams = teamIds.subtracting(listeners.keys)
        if !newTeams.isEmpty { isLoading = true }
        for id in newTeams {
            listenToEvents(of: id)
        }
    }

    // MARK: - Creating

    func createEvent(_ build: (String) -> Event) async throws {
        guard let uid else { throw EventServiceError.notSignedIn }

        let event = build(uid)
        let ref = Firestore.firestore().collection("events").document()
        try await ref.setData(Firestore.Encoder().encode(event))
    }

    // MARK: - Private

    private func listenToEvents(of teamId: String) {
        let startOfToday = Calendar.current.startOfDay(for: .now)

        let listener = Firestore.firestore()
            .collection("events")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
            .order(by: "startAt")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in
                        guard let self, self.listeners[teamId] != nil else { return }
                        self.report(error)
                        self.isLoading = false
                    }
                    return
                }

                let events = snapshot?.documents.compactMap {
                    try? $0.data(as: Event.self)
                } ?? []

                Task { @MainActor in
                    guard let self, self.listeners[teamId] != nil else { return }
                    self.eventsByTeam[teamId] = events
                    self.isLoading = false
                }
            }

        listeners[teamId] = listener
    }

    private func report(_ error: Error) {
        #if DEBUG
        print("EventService:", error)
        #endif
        errorMessage = String(localized: "Termine konnten nicht geladen werden.")
    }
}

extension EventService {
    nonisolated static func message(for error: Error) -> String {
        if let error = error as? EventServiceError {
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
