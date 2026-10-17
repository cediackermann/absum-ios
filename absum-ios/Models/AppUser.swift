//
//  AppUser.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//
import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable{
    @DocumentID var id: String?
    var displayName: String
    var photoURL: String?
    var locale: String = "de"
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    
    static var currentLocale: String {
        Locale.current.language.languageCode == "en" ? "en" : "de"
    }
}
