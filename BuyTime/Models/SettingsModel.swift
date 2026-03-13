//
//  SettingsModel.swift
//  BuyTime
//
//  Created by Baalavignesh Arunachalam on 1/7/26.
//

import Foundation
import SwiftUI

struct Legal: Hashable {
    let name: String
    let imageName: String
}

var legalList: [Legal] = [
    .init(name: "Term of Use", imageName: "book.pages"),
    .init(name: "Privacy Policy", imageName: "hand.raised")
]
