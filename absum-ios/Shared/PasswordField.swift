//
//  PasswordField.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI

struct PasswordField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var contentType: UITextContentType = .password

    @State private var isVisible = false
    @FocusState private var focus: Bool?

    var body: some View {
        HStack {
            ZStack {
                SecureField(title, text: $text)
                    .focused($focus, equals: false)
                    .opacity(isVisible ? 0 : 1)
                TextField(title, text: $text)
                    .focused($focus, equals: true)
                    .opacity(isVisible ? 1 : 0)
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                let wasFocused = focus != nil
                isVisible.toggle()
                if wasFocused { focus = isVisible }
            } label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Passwort verbergen" : "Passwort anzeigen")
        }
    }
}
