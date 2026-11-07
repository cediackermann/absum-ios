//
//  JoinTeamView.swift
//  absum-ios
//
//  Created by cediackermann on 02.11.2026.
//

import SwiftUI

struct JoinTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ClubService.self) private var clubService
    @Environment(AuthService.self) private var auth

    @State private var code: String
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var joinedStatus: MembershipStatus?

    init(initialCode: String = "") {
        _code = State(initialValue: initialCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Code", text: $code, prompt: Text("z. B. K7QM4XRT"))
                        .font(.system(.title3, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.join)
                        .onSubmit { Task { await join() } }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("Den Code bekommst du von deinem Trainer.")
                    }
                }
            }
            .navigationTitle("Team beitreten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button(role: .confirm) {
                            Task { await join() }
                        }
                        .disabled(!canJoin)
                    }
                }
            }
            .alert(
                joinedStatus == .pending ? "Anfrage gesendet" : "Willkommen im Team",
                isPresented: Binding(
                    get: { joinedStatus != nil },
                    set: { if !$0 { dismiss() } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(joinedStatus == .pending
                     ? "Dein Trainer muss deine Anfrage noch bestätigen."
                     : "Du bist jetzt Mitglied des Teams.")
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private var canJoin: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
            && auth.profile != nil
            && !isWorking
    }

    private func join() async {
        guard canJoin else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            joinedStatus = try await clubService.join(
                code: code,
                displayName: auth.profile?.displayName ?? "",
                photoURL: auth.profile?.photoURL
            )
        } catch {
            errorMessage = ClubService.message(for: error)
        }
    }
}
