import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
        if isAuthenticated {
            TabView {
                SocialFeedView()
                    .tabItem {
                        Label("Feed", systemImage: "list.bullet")
                    }
                
                if #available(iOS 17.0, *) {
                    ScanningView()
                        .tabItem {
                            Label("Scan", systemImage: "camera.viewfinder")
                        }
                }
                
                ProfileView(isCurrentUser: true)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }
        } else {
            AuthView(isAuthenticated: $isAuthenticated)
        }
    }
}
