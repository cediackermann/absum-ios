//
//  ClubService.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation
import FirebaseFirestore
import Observation

enum ClubServiceError: Error {
    case notSignedIn
    case invalidName
    case invalidDate
}

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
    private var teamListeners: [String: ListenerRegistration] = [:]
    private var clubListeners: [String: ListenerRegistration] = [:]
    
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
                    self?.handle(memberships:memberships, for:uid)
                }
            }
    }
    
    func stop() {
        membershipListener?.remove()
        membershipListener = nil

        teamListeners.values.forEach { $0.remove() }
        teamListeners = [:]
        clubListeners.values.forEach { $0.remove() }
        clubListeners = [:]

        memberships = []
        teams = [:]
        clubs = [:]
        errorMessage = nil
        isLoading = false
        uid = nil
    }
    
    // MARK: - Clubs
    
    func createClub(name: String, displayName: String, photoURL: String?) async throws {
        guard let uid else {
            throw ClubServiceError.notSignedIn
        }
        
        let db = Firestore.firestore()
        
        let clubRef = db.collection("clubs").document()
        let membershipRef = db.collection("memberships")
                .document(Membership.clubDocumentID(clubId: clubRef.documentID, uid: uid))
        
        let club = Club(id: nil, name: name, createdBy: uid)
        let membership = Membership.clubAdmin(
            uid: uid,
            clubId: clubRef.documentID,
            displayName: displayName,
            photoURL: photoURL
        )
        
        let batch = db.batch()
        try batch.setData(from: club, forDocument: clubRef)
        try batch.setData(from: membership, forDocument: membershipRef)
        try await batch.commit()
    }
    
    // MARK: - Teams
    
    @discardableResult
    func createTeam(
        name: String,
        sport: String?,
        in clubId: String,
        addMeAsCoach: Bool,
        displayName: String,
        photoURL: String?
    ) async throws -> String {
        guard let uid else { throw ClubServiceError.notSignedIn }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw ClubServiceError.invalidName }

        let sport = sport?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSport = (sport?.isEmpty ?? true) ? nil : sport

        let db = Firestore.firestore()
        let teamRef = db.collection("teams").document()
        let membershipRef = db.collection("memberships")
            .document(Membership.teamDocumentID(teamId: teamRef.documentID, uid: uid))

        let team = Team(
            id: nil,
            clubId: clubId,
            name: name,
            sport: cleanSport,
            timezone: TimeZone.current.identifier,
            archived: false,
            settings: TeamSettings(),
            createdAt: nil
        )
        
        try await teamRef.setData(Firestore.Encoder().encode(team))

        if addMeAsCoach {
            let membership = Membership.coach(
                uid: uid,
                clubId: clubId,
                teamId: teamRef.documentID,
                displayName: displayName,
                photoURL: photoURL
            )
            try await membershipRef.setData(Firestore.Encoder().encode(membership))
        }

        return teamRef.documentID
    }
    
    // MARK: - Invites
    
    @discardableResult
    func createInvite(
        teamId: String,
        clubId: String,
        requiresApproval: Bool,
        expiresAt: Date
    ) async throws -> Invite {
        guard let uid else { throw ClubServiceError.notSignedIn }

        let maxDate = Date.now.addingTimeInterval(90 * 24 * 60 * 60)
        guard expiresAt > .now, expiresAt < maxDate else {
            throw ClubServiceError.invalidDate
        }

        let code = Invite.generateCode()
        var invite = Invite(
            id: nil,
            teamId: teamId,
            clubId: clubId,
            requiresApproval: requiresApproval,
            revoked: false,
            expiresAt: expiresAt,
            createdBy: uid,
            createdAt: nil
        )

        
        let inviteRef = Firestore.firestore().collection("invites").document(code)
        try await inviteRef.setData(Firestore.Encoder().encode(invite))

        invite.id = code
        return invite
    }
    
    func currentInvite(teamId: String, clubId: String) async throws -> Invite {
        let snapshot = try await Firestore.firestore()
            .collection("invites")
            .whereField("teamId", isEqualTo: teamId)
            .whereField("clubId", isEqualTo: clubId)
            .whereField("revoked", isEqualTo: false)
            .getDocuments()

        let invites = snapshot.documents.compactMap {
            try? $0.data(as: Invite.self)
        }

        if let existing = invites
            .filter({ $0.isUsable })
            .max(by: { $0.expiresAt < $1.expiresAt }) {
            return existing
        }

        return try await createInvite(
            teamId: teamId,
            clubId: clubId,
            requiresApproval: true,
            expiresAt: .now.addingTimeInterval(30 * 24 * 60 * 60)
        )
    }
    
    //MARK: - Private
    
    private func listenToTeam(_ id: String, for uid: String) {
        let listener = Firestore.firestore()
            .collection("teams").document(id)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in
                        guard let self, self.uid == uid else { return }
                        if self.teams[id] == nil { self.report(error) }
                    }
                    return
                }

                let team = try? snapshot?.data(as: Team.self)

                Task { @MainActor in
                    guard let self, self.uid == uid else { return }
                    self.teams[id] = team
                }
            }

        teamListeners[id] = listener
    }
    
    private func listenToClub(_ id: String, for uid: String) {
        let listener = Firestore.firestore()
            .collection("clubs").document(id)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    Task { @MainActor in
                        guard let self, self.uid == uid else { return }
                        if self.clubs[id] == nil { self.report(error) }
                    }
                    return
                }
                let club = try? snapshot?.data(as: Club.self)
                
                Task { @MainActor in
                    guard let self, self.uid == uid else { return }
                    self.clubs[id] = club
                }
            }
        
        clubListeners[id] = listener
    }
    
    private func report(_ error: Error) {
        #if DEBUG
        print("ClubService:", error)
        #endif
        errorMessage = String(localized: "Teams konnten nicht geladen werden.")
    }
    
    private func handle(memberships: [Membership], for uid: String) {
        self.memberships = memberships
        errorMessage = nil

        let teamIds = Set(memberships.compactMap(\.teamId))
        let clubIds = Set(memberships.map(\.clubId))

        // 1. Stop listening to teams and clubs you no longer belong to.
        for id in teamListeners.keys where !teamIds.contains(id) {
            teamListeners[id]?.remove()
            teamListeners[id] = nil
            teams[id] = nil
        }
        for id in clubListeners.keys where !clubIds.contains(id) {
            clubListeners[id]?.remove()
            clubListeners[id] = nil
            clubs[id] = nil
        }

        // 2. Start listening to new ones. "New" = nobody is listening yet.
        for id in teamIds.subtracting(teamListeners.keys) {
            listenToTeam(id, for: uid)
        }
        for id in clubIds.subtracting(clubListeners.keys) {
            listenToClub(id, for: uid)
        }

        isLoading = false
    }
}

extension ClubService {
    nonisolated static func message(for error: Error) -> String {
        if let error = error as? ClubServiceError {
            switch error {
            case .notSignedIn:
                return String(localized: "Du bist nicht angemeldet.")
            case .invalidName:
                return String(localized: "Der Name muss zwischen 1 und 80 Zeichen lang sein.")
            case .invalidDate:
                return String(localized: "Ungültiges Verfallsdatum")
            }
        }

        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
            switch code {
            case .permissionDenied:
                return String(localized: "Dazu hast du keine Berechtigung.")
            case .unavailable:
                return String(localized: "Keine Verbindung. Bitte versuche es später nochmals.")
            default:
                break
            }
        }
        return String(localized: "Etwas ist schiefgelaufen. Bitte versuche es nochmals.")
    }
}
