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

    private enum Field {
        case email, password, confirmPassword
    }
    @FocusState private var focusedField: Field?
    
    private func onSubmit() {
        Task {
            switch viewModel.flow {
            case .login:
                await viewModel.signInWithEmailPassword()
            case .signUp:
                await viewModel.signUpWithEmailPassword()
            }
        }
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
                    .onSubmit { focusedField = .confirmPassword }
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
                        if viewModel.authenticationState == .authenticating {
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
                    !viewModel.isValid || viewModel.authenticationState == .authenticating
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

