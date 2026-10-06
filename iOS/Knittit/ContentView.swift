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
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    FeedView()
                        .tag(0)
                    
                    ScanFlowWrapper(selectedTab: $selectedTab)
                        .tag(1)
                    
                    ProfileView(targetUserId: nil, isCurrentUser: true, isTabRoot: true)
                        .tag(2)
                }
                .toolbar(.hidden, for: .tabBar)
                
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
