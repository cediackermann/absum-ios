//
//  AuthenticationView.swift
//  absum-ios
//
//  Created by cediackermann on 17.10.2026.
//

import SwiftUI
import Combine

struct AuthenticationView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel
    @Environment(AuthService.self) private var auth

    private enum Field {
        case firstName, lastName, email, password
    }
    @FocusState private var focusedField: Field?
    
    private func onSubmit() {
        focusedField = nil
        Task { await viewModel.submit(using: auth) }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        
        Form {
            Section {
                AuthHeader(subtitle: viewModel.flow == .login
                                   ? "Termine und Anwesenheit für dein Team."
                                   : "Erstelle ein Konto, um deinem Team beizutreten.")
            }
            .listRowBackground(Color.clear)
            
            Section {
                if viewModel.flow == .signUp {
                    TextField("Vorname", text: $viewModel.firstName)
                        .focused($focusedField, equals: .firstName)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }
                    
                    TextField("Nachname", text: $viewModel.lastName)
                        .focused($focusedField, equals: .lastName)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                }
                TextField("E-Mail", text: $viewModel.email)
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                
                PasswordField(title: "Passwort", text: $viewModel.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit { onSubmit() }
            } footer: {
                HStack {
                    Spacer()
                    Button("Passwort vergessen?") {
                    }
                }
            }
            
            Section {
                Button {
                    onSubmit()
                } label: {
                    Group {
                        if auth.state == .checking {
                            ProgressView()
                        } else {
                            Text(viewModel.flow == .login ? "Anmelden" : "Konto erstellen")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(
                    !viewModel.isValid || auth.state == .checking
                )
            } footer: {
                HStack {
                    if viewModel.flow == .login {
                        Text("Noch kein Konto?")
                        Button("Konto erstellen") {
                            withAnimation { viewModel.switchFlow() }
                        }
                    } else {
                        Text("Bereits ein Konto?")
                        Button("Anmelden") {
                            withAnimation { viewModel.switchFlow() }
                        }
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}

#Preview {
    RootView()
        .environment(AuthenticationViewModel())
}
