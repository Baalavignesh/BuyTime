//
//  PermissionView.swift
//  BuyTime
//
//  Screen Time authorization prompt shown on first launch or when denied.
//

import SwiftUI

struct PermissionView: View {
    let authManager: AuthorizationManager

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                Button {
                    Task {
                        await authManager.requestAuthorization()
                    }
                } label: {
                    Image("permission")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .clipShape(.rect(cornerRadius: 32))
                        .padding(12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.blue, lineWidth: 1)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Image(systemName: "arrow.up")
                                .font(.title)
                                .imageScale(.large)
                                .offset(x: 72, y: 52)
                        }
                }
                .buttonStyle(PressableStyle())

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Text("Private by Design")
                    .font(.largeTitle).multilineTextAlignment(.center)

                Text("We can't see your apps or how you use them. ByTime will need your permission to continue.")
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Text("Your sensitive data is handled by Apple and never leaves your device.")
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
