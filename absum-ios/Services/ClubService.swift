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
    
    func createClub(name: String, displayName: String, photoURL: String?) async throws {
        guard let uid else { return }
        
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
            let teamRef = db.collection("teams").document(id)
            
            if let cached = try? await teamRef.getDocument(source: .cache).data(
                as: Team.self
            ) {
                teams[id] = cached
            }
            
            do {
                let fresh = try await teamRef.getDocument(source: .server).data(as: Team.self)
                guard self.uid == uid else { return }
                teams[id] = fresh
            } catch {
                report(error)
            }
        }
        
        for id in missingClubs {
            let clubRef = db.collection("clubs").document(id)
            if let cached = try? await clubRef.getDocument(source: .cache).data(
                as: Club.self
            ) {
                clubs[id] = cached
            }
            do {
                let fresh = try await clubRef.getDocument(source: .server).data(as: Club.self)
                guard self.uid == uid else { return }
                clubs[id] = fresh
            } catch {
                report(error)
            }
        }
        
        errorMessage = nil
        self.isLoading = false
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
