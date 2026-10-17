//
//  AuthHeader.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct AuthHeader: View {
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(.blue.gradient, in: .rect(cornerRadius: 20))
                .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
                .padding(.bottom, 8)

            Text("Absum")
                .font(.largeTitle.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
