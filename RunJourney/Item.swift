//
//  Item.swift
//  RunJourney
//
//  Created by Kenta Nakamura on 2026/05/01.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
