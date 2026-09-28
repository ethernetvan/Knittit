//
//  ContentView.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        LibraryGridView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: KnitProject.self, inMemory: true)
}
