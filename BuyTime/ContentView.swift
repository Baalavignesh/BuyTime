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
            Color.black.ignoresSafeArea()
        } else if clerk.session != nil {
            ParentView()
        } else {
            VStack {
                Spacer()
                Text("ByTime")
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding(32)
                Text("A practical productivity tool that you won't uninstall after a week")
                    .padding(16)
                    .font(.body)
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    Task { await signInWithOAuth(provider: .google) }
                } label: {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .light ? Color.black : Color.clear, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                Button {
                    Task { await signInWithOAuth(provider: .apple) }
                } label: {
                    Image("apple")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white : Color.clear, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .padding(10)
        }
    }
}

extension ContentView {

  func signInWithOAuth(provider: OAuthProvider) async {
    do {
      let result = try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: provider))

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
      dump(error)
    }
  }
}

#Preview {
    ContentView(isClerkLoaded: true)
}
