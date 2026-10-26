//
//  CreateTeamView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import Foundation
import SwiftUI

struct CreateTeamView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ClubService.self) var clubService
    
    @State private var name = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Team Name", text: $name)
                    .textContentType(.organizationName)
            }
            .navigationTitle("Neues team")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .accessibilityLabel("Cancel")
                        }
                    }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func create() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            dismiss()
        } catch {
            errorMessage = String(localized: "Das Team konnte nicht erstellt werden.")
        }
    }
}
