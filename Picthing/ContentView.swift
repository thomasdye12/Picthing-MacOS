//
//  ContentView.swift
//  Picthing
//
//  Created by Thomas Dye on 14/07/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var jwtToken: String = ""
    @State private var SessionID: String = ""
    @State private var savedMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your JWT Token")
                .font(.headline)
            TextField("Clerk RefreshToken", text: $jwtToken)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Clerk SessionID", text: $SessionID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button("Save") {
                saveToken()
            }
            .buttonStyle(.borderedProminent)
            if let savedMessage = savedMessage {
                Text(savedMessage).foregroundColor(.green)
            }
            
            Text("""
                SessionID: This is the cookie with the name 'clerk_active_context' 
                RefreshToken: This is the cookie with the name '__client' 
                
                
                This app is not associated with Ping.gg, and is something I Thomas Dye Has build please contact apple@thomasdye.net if you have any issues
                """)
        }
        .padding()
        .onAppear {
            loadTokens()
        }
    }
    
    func saveToken() {
        // Replace with your actual App Group identifier
        // This must match your provisioning profile and any extension's identifier
        let appGroupID = "group.PicThingExtention"
        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            userDefaults.set(jwtToken, forKey: "jwtToken")
            userDefaults.set(SessionID, forKey: "SessionID")
            savedMessage = "Token saved!"
        } else {
            savedMessage = "Failed to save token. Check app group settings."
        }
    }
    
    func loadTokens() {
        let appGroupID = "group.PicThingExtention"
        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            jwtToken = userDefaults.string(forKey: "jwtToken") ?? ""
            SessionID = userDefaults.string(forKey: "SessionID") ?? ""
        }
    }
}

#Preview {
    ContentView()
}
