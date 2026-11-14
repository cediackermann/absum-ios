//
//  EventCreationViewModel.swift
//  absum-ios
//
//  Created by cediackermann on 09.11.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class EventCreationViewModel {
    let teamId: String
    let clubId: String

    var type: EventType = .training
    var title = ""

    var startAt: Date {
        didSet {
            endAt = startAt.addingTimeInterval(endAt.timeIntervalSince(oldValue))
        }
    }
    var endAt: Date

    var meetOffset: Int? = nil
    var reminderOffset: Int?
    var lockOffset: Int?

    var locationName = ""
    var locationAddress = ""
    var notes = ""

    private(set) var isWorking = false
    var errorMessage: String?

    init(teamId: String, clubId: String, settings: TeamSettings, now: Date = .now) {
        self.teamId = teamId
        self.clubId = clubId

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        self.startAt = start
        self.endAt = start.addingTimeInterval(90 * 60)

        self.reminderOffset = settings.defaultReminderOffsetMin
        self.lockOffset = settings.defaultLockOffsetMin
    }

    // MARK: - Validation

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty
            && trimmedTitle.count <= 80
            && endAt > startAt
            && (meetOffset ?? 0) >= 0
            && (reminderOffset.map { $0 > 0 } ?? true)
            && (lockOffset.map { $0 >= 0 } ?? true)
            && notes.count <= 1000
    }

    // MARK: - Building the event

    func makeEvent(createdBy uid: String) -> Event {
        func before(_ minutes: Int?) -> Date? {
            minutes.map { startAt.addingTimeInterval(-Double($0) * 60) }
        }

        let name = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return Event(
            id: nil,
            teamId: teamId,
            clubId: clubId,
            type: type,
            title: trimmedTitle,
            startAt: startAt,
            endAt: endAt,
            meetAt: (meetOffset ?? 0) > 0 ? before(meetOffset) : nil,
            location: name.isEmpty ? nil : EventLocation(name: name, address: address.isEmpty ? nil : address),
            notes: note.isEmpty ? nil : note,
            status: .scheduled,
            reminderAt: before(reminderOffset),
            lockAt: before(lockOffset),
            remindedAt: nil,
            seriesId: nil,
            isException: nil,
            createdBy: uid,
            createdAt: nil,
            updatedAt: nil,
            updatedBy: uid
        )
    }
}
