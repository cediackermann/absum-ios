//
//  InviteView.swift
//  absum-ios
//
//  Created by cediackermann on 01.11.2026.
//

import Foundation
import SwiftUI

struct InviteView: View {
    @Environment(ClubService.self) private var clubService
    @State private var invite: Invite?
    @State private var errorMessage: String?
    
    let teamId: String
    let clubId: String
    
    var body: some View {
        VStack {
            if let invite {
                    Text(invite.code)
                    QRCodeView(text: invite.code)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }
        }
        .task {
            do {
                invite = try await clubService.currentInvite(
                    teamId: teamId,
                    clubId: clubId
                )
            } catch {
                errorMessage = ClubService.message(for: error)
            }
        }
    }
}
