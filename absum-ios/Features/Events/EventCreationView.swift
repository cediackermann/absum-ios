//
//  EventCreationView.swift
//  absum-ios
//
//  Created by cediackermann on 09.11.2026.
//

import SwiftUI

struct EventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EventCreationViewModel.self) private var viewModel
    @Environment(EventService.self) private var eventService
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                }
                
                Section("Zeit") {
                    DatePicker("Beginn", selection: $viewModel.startAt)
                    DatePicker("Ende", selection: $viewModel.endAt)
                    Picker("Treffpunkt", selection: $viewModel.meetOffset) {
                        Text("Kein").tag(Int?.none)
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) Min. vorher").tag(Int?.some(minutes))
                        }
                    }
                    Picker("Antworten bis", selection: $viewModel.lockOffset) {
                        Text("Start").tag(Int?.none)
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) Min. vorher").tag(Int?.some(minutes))
                        }
                    }
                }
                
                Section("Standort") {
                    TextField("Name", text: $viewModel.locationName)
                        .focused($focusedField, equals: .locationName)
                        .submitLabel(.next)
                        .onSubmit{ focusedField = .locationAddress }
                    
                    TextField("Addresse", text: $viewModel.locationAddress)
                        .focused($focusedField, equals: .locationAddress)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .notes }
                }
                
                Section("Notizen") {
                    TextField("Notizen", text: $viewModel.notes, prompt: Text("Optional"), axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedField, equals: .notes)
                }
            }
            .navigationTitle("Neuer Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Button(role: .confirm) { submit() }
                            .disabled(!viewModel.isValid)
                    }
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func submit() {
        focusedField = nil
            Task {
                if await viewModel.submit(using: eventService) {
                    dismiss()
                }
            }
        }
    
    private enum Field {
        case title
        case locationName
        case locationAddress
        case notes
    }
}

#Preview {
    EventCreationView()
        .environment(
            EventCreationViewModel(
                teamId: "T1",
                clubId: "C1",
                settings: TeamSettings()
            )
        )
}

