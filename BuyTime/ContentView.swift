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

    @State private var shaderStart: Date = .now

    var body: some View {
        if !isClerkLoaded {
            Color.black.ignoresSafeArea()
        } else if clerk.session != nil {
            ParentView()
        } else {
            ZStack {
                shaderBackground

                VStack {
                    Spacer()
                    Text("ByTime")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(32)
                    Text("We both know you're not giving up your phone. So let's make a deal — earn your screen time by actually getting things done first.")
                        .padding(16)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
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
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
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
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .padding(10)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Shader Background

    @ViewBuilder
    private var shaderBackground: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(shaderStart)
            GeometryReader { geo in
                Color.black
                    .colorEffect(
                        ShaderLibrary.focusBackground(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(Float(elapsed)),
                            .float(1.0)
                        )
                    )
            }
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
