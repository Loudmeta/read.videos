import SwiftUI

struct FooterNavigationView: View {
    @Binding var selectedTab: MainView.Tab
    
    var body: some View {
        HStack {
            Button(action: { selectedTab = .home }) {
                Image(systemName: "house")
                Text("Home")
            }
            Spacer()
            Button(action: { selectedTab = .settings }) {
                Image(systemName: "gear")
                Text("Settings")
            }
            Spacer()
            Button(action: { selectedTab = .account }) {
                Image(systemName: "person")
                Text("Account")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}

struct FooterNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        FooterNavigationView(selectedTab: .constant(.home))
    }
}
