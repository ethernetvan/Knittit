//
//  ContentView.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false

    var body: some View {
        if isLoggedIn {
            LibraryGridView()
        } else {
            SupabaseLoginView(isLoggedIn: $isLoggedIn)
                .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: KnitProject.self, inMemory: true)
}
