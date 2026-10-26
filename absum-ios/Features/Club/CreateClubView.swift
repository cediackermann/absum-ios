//
//  CreateClubView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import Foundation
import SwiftUI

struct CreateClubView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ClubService.self) var clubService
    
    @State private var name = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Club Name", text: $name)
                    .textContentType(.organizationName)
            }
            .navigationTitle("Neuer Club")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .accessibilityLabel("Cancel")
                        }
                    }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Task {
                            await create()
                        }
                    } label: {
                        if isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .accessibilityLabel("Confirm")
                        }
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }
    
    // MARK: - Private
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func create() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await clubService.createClub(
                name: name,
                displayName: name,
                photoURL: nil
            )
            dismiss()
        } catch {
            errorMessage = ClubService.message(for: error)
        }
    }
}
