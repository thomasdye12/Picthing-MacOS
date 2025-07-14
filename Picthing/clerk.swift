//
//  clerk.swift
//  Picthing
//
//  Created by Thomas Dye on 14/07/2025.
//

import Foundation
class clerk {
    
    static  func fetchClerkToken(clientToken: String,sessionID: String) async throws -> String {
        // Create URL
        guard let url = URL(string: "https://clerk.ping.gg/v1/client/sessions/\(sessionID.trimmingCharacters(in: CharacterSet(charactersIn: ":")))/tokens?__clerk_api_version=2025-04-10&_clerk_js_version=5.71.0") else {
            throw NSError(domain: "InvalidURL", code: 400, userInfo: nil)
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "organization_id=".data(using: .utf8)
        
        // Set headers
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("gzip, deflate, br, zstd", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://pic.ping.gg", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("16", forHTTPHeaderField: "Content-Length")
        request.setValue("https://pic.ping.gg/", forHTTPHeaderField: "Referer")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("__client=\(clientToken)", forHTTPHeaderField: "Cookie")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status code
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
        }
        
        // Parse response
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jwt = jsonObject["jwt"] as? String else {
            throw NSError(domain: "InvalidResponse", code: 500, userInfo: nil)
        }
        
        return jwt
    }
    
    
}
