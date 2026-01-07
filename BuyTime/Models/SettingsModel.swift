//
//  SettingsModel.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import SwiftUI

struct Account: Hashable {
    let name: String
    let imageName: String
    let color: Color
}

struct Support: Hashable {
    let name: String
    let imageName: String
    let color: Color
}

struct Legal: Hashable {
    let name: String
    let imageName: String
    let color: Color
}

var accountList: [Account] = [
    .init(name: "Personal Info", imageName: "person.circle", color: Color.blue),
    .init(name: "App Selection", imageName: "apps.iphone.badge.plus", color: Color.blue),
    .init(name: "Log out", imageName: "arrow.left.circle", color: Color.blue)
]

var supportList: [Support] = [
    .init(name: "Get Help", imageName: "questionmark.circle", color: Color.blue),
    .init(name: "Feedback", imageName: "exclamationmark.message", color: Color.blue)
]

var legalList: [Legal] = [
    .init(name: "Term of Use", imageName: "book.pages", color: Color.blue),
    .init(name: "Privacy Policy", imageName: "hand.raised", color: Color.blue)
]
