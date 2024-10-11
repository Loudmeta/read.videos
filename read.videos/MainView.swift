import SwiftUI

struct MainView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home, edit, settings, account
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            VideoEditingView()
                .tabItem {
                    Label("Edit", systemImage: "video.badge.plus")
                }
                .tag(Tab.edit)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
            
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(Tab.account)
        }
        .accentColor(.blue)
        .preferredColorScheme(.dark)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
