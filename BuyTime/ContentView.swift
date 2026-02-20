//
//  ContentView.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 12/17/25.
//

import SwiftUI
import Clerk
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift


struct ContentView: View {
    let isClerkLoaded: Bool
    @Environment(\.clerk) private var clerk
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !isClerkLoaded {
            // Clerk is still restoring the session — show nothing to avoid
            // flashing the auth screen for already signed-in users.
            Color.black.ignoresSafeArea()
        } else if clerk.session != nil {
            ParentView()
        } else {
            VStack {
                VStack {
                    Spacer()
                    Text("BuyTime")
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .padding(32)
                    Text("A practical productivity tool that you won't uninstall after a week").padding(16)
                        .font(.default)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .light ? Color.black : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            Task { await signInWithOAuth(provider: .google) }
                        }
                        .padding(.bottom, 8)
                        
                    Image("apple")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            Task { await signInWithOAuth(provider: .apple) }
                        }
                        .padding(.bottom, 8)
                }
            }
            .padding(10)
        }
    }
}

extension ContentView {

  func signInWithOAuth(provider: OAuthProvider) async {
    do {
      // Start the sign-in process using the selected OAuth provider.
      let result = try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: provider))

      // It is common for users who are authenticating with OAuth to use
      // a sign-in button when they mean to sign-up, and vice versa.
      // Clerk will handle this transfer for you if possible.
      // Therefore, a TransferFlowResult can be either a SignIn or SignUp.

      switch result {
      case .signIn(let signIn):
        switch signIn.status {
        case .complete:
          break // Clerk automatically updates the session; view reacts
        default:
          // If the status is not complete, check why. User may need to
          // complete further steps.
          dump(signIn.status)
        }
      case .signUp(let signUp):
        switch signUp.status {
        case .complete:
          break // Clerk automatically updates the session; view reacts
        default:
          // If the status is not complete, check why. User may need to
          // complete further steps.
          dump(signUp.status)
        }
      }
    } catch {
      // See https://clerk.com/docs/guides/development/custom-flows/error-handling
      // for more info on error handling.
      dump(error)
    }
  }
}

#Preview {
    ContentView(isClerkLoaded: true)
}
