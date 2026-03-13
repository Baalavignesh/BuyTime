//
//  FormatUtils.swift
//  BuyTime
//
//  Shared formatting utilities used across multiple views.
//

import Foundation

enum FormatUtils {
    static func duration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes) min"
    }
}
