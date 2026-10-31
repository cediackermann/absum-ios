//
//  InviteTest.swift
//  absum-ios
//
//  Created by cediackermann on 31.10.2026.
//

import Testing
@testable import absum_ios

@Test func `Invite code is 8 characters long`() {
    #expect(Invite.generateCode().count == 8)
}

@Test func `Code only uses characters from the alphabet`() {
    let code = Invite.generateCode()
    #expect(code.allSatisfy { Invite.alphabet.contains($0) })
}

@Test func `Invite code is randomly generated`() async throws {
    var codes: Set<String> = []
    for _ in 1...1000 {
        codes.insert(Invite.generateCode())
    }
    #expect(codes.count == 1000)
}
