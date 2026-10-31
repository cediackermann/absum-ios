//
//  TeamDetailView.swift
//  absum-ios
//
//  Created by cediackermann on 26.10.2026.
//

import SwiftUI

struct TeamDetailView: View {
    @Environment(ClubService.self) private var clubService
    
    let teamId: String
    private var team: Team? { clubService.teams[teamId] }
    
    var body: some View {
        
    }
}
