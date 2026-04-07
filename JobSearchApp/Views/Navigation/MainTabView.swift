import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
            ApplicationsView()
                .tabItem { Label("Applications", systemImage: "briefcase") }
            DocumentsView()
                .tabItem { Label("Documents", systemImage: "doc.text") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}
