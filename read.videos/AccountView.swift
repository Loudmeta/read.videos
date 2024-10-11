import SwiftUI

struct AccountView: View {
    @State private var username = "JohnDoe"
    @State private var email = "john.doe@example.com"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            TextField("Username", text: $username)
                                .font(.headline)
                            TextField("Email", text: $email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical)
                }
                
                Section(header: Text("Account Settings")) {
                    NavigationLink(destination: Text("Change Password")) {
                        Label("Change Password", systemImage: "lock")
                    }
                    NavigationLink(destination: Text("Notification Settings")) {
                        Label("Notifications", systemImage: "bell")
                    }
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Label("Privacy", systemImage: "hand.raised")
                    }
                }
                
                Section {
                    Button(action: {
                        // Implement logout functionality
                    }) {
                        Text("Log Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
