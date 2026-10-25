//
//  AppUser.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var photoURL: String?
    var locale: AppLocale
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
}

enum AppLocale: String, Codable, CaseIterable {
    case germanSwitzerland = "de-CH"
    case english = "en"

    static var current: AppLocale {
        Locale.current.language.languageCode == "en" ? .english : .germanSwitzerland
    }
}
