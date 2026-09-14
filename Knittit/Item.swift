//
//  Item.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
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
