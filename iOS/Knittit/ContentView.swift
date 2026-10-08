//
//  ContentView.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var selectedTab: Int = 0

    var body: some View {
        if isLoggedIn {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tabItem {
                        Label("Feed", systemImage: "list.bullet")
                    }
                    .tag(0)
                
                ScanFlowWrapper(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Scan", systemImage: "viewfinder")
                    }
                    .tag(1)
                
                ProfileView(targetUserId: nil, isCurrentUser: true, isTabRoot: true)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle.fill")
                    }
                    .tag(2)
            }
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
