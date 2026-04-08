import SwiftUI

struct MainTabView: View {
    var body: some View {
        if #available(iOS 18, *) {
            TabView {
                Tab("Discover", systemImage: "magnifyingglass") {
                    DiscoverView()
                }
                Tab("Applications", systemImage: "briefcase") {
                    ApplicationsView()
                }
                Tab("Documents", systemImage: "doc.text") {
                    DocumentsView()
                }
                Tab("Profile", systemImage: "person.circle") {
                    ProfileView()
                }
            }
        } else {
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
}
