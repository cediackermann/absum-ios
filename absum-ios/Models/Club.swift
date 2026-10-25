//
//  Club.swift
//  absum-ios
//
//  Created by cediackermann on 25.10.2026.
//

import Foundation
import FirebaseFirestore

struct Club: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var createdBy: String
    @ServerTimestamp var createdAt: Date?
}
