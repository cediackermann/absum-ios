//
//  EventsView.swift
//  absum-ios
//
//  Created by cediackermann on 16.11.2026.
//

import SwiftUI

struct EventsView: View {
    @Environment(EventService.self) private var eventService
    @Environment(ClubService.self) private var clubService
    
    @State private var selectedTeamId: String?
    
    var body: some View {
        List {
            ForEach(days) { day in
                Section(header(for: day.date)) {
                    ForEach(day.events) { event in
                        EventRow(event: event,                             teamName: selectedTeamId == nil ? clubService.teams[event.teamId]?.name : nil
)
                    }
                }
            }
        }
        .animation(.default, value: selectedTeamId)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        .toolbarTitleMenu {
            if sortedTeams.count > 1 {
                Picker("Team", selection: $selectedTeamId) {
                    Text("Alle Termine").tag(String?.none)
                    ForEach(sortedTeams, id: \.id) { team in
                        Text(team.name).tag(team.id)
                    }
                }
            }
        }
    }
    
    
    
    private var sortedTeams: [Team] {
       clubService.teams.values.sorted { $0.name < $1.name }
   }
    
    private var title: String {
        if let selectedTeamId, let team = clubService.teams[selectedTeamId] {
            team.name
        } else {
            String(localized: "Termine")
        }
    }
    
    // MARK: - Data

    private struct EventDay: Identifiable {
        let date: Date
        let events: [Event]
        var id: Date { date }
    }
    
    private var visibleEvents: [Event] {
        if let selectedTeamId {
            eventService.events(for: selectedTeamId)
        } else {
            eventService.events
        }
    }
    
    private var days: [EventDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEvents) { calendar.startOfDay(for: $0.startAt) }
        return grouped.keys.sorted().map { date in
            EventDay(date: date, events: grouped[date] ?? [])
        }
    }
    
    // MARK: - Texts

    private func header(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Heute") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Morgen") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
