//
//  KnittitApp.swift
//  Knittit
//
//  Created by Evan Thomas on 9/14/26.
//

import SwiftUI
import SwiftData

@main
struct KnittitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            KnitProject.self, ProjectVersion.self, SyncAction.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView().onAppear { _ = SyncManager.shared }
        }
        .modelContainer(sharedModelContainer)
    }
}
