//
//  UploadThing.swift
//  Picthing
//
//  Created by Thomas Dye on 14/07/2025.
//

struct UploadURLResponse: Codable {
    let url: String
    let key: String
    let name: String
    let customId: String?
}

struct FileInfo {
    let name: String
    let size: Int
    let type: String
    let lastModified: Int
}

struct UploadResponse: Codable {
    let ufsUrl: String
    let url: String
    let appUrl: String
    let fileHash: String
    let serverData: ServerData
    
    struct ServerData: Codable {
        let uploadedBy: String
    }
}

import Foundation
class UploadThing {
  

    static func initiateUploadThing(jwtToken: String,sessionID:String, files: [FileInfo]) async throws -> [UploadURLResponse] {
        // Create URL
        guard let url = URL(string: "https://pic.ping.gg/api/uploadthing?actionType=upload&slug=imageUploader") else {
            throw NSError(domain: "InvalidURL", code: 400, userInfo: nil)
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create JSON body
        let fileInfoArray = files.map { file -> [String: Any] in
            return [
                "name": file.name,
                "size": file.size,
                "type": file.type,
                "lastModified": file.lastModified
            ]
        }
        
        let body = ["files": fileInfoArray]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // Set headers
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("7.0.2", forHTTPHeaderField: "x-uploadthing-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("@uploadthing/react", forHTTPHeaderField: "x-uploadthing-package")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://pic.ping.gg", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("https://pic.ping.gg/app", forHTTPHeaderField: "Referer")
        request.setValue("en-GB,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        
        // Set cookie with the JWT token
        let cookieString = "_client_uat=\(Date().timeIntervalSince1970); __refresh_GWM5vUtE=jO7vgwLHERXkcKnnut5M; __client_uat_GWM5vUtE=\(Date().timeIntervalSince1970); clerk_active_context=\(sessionID);__session=\(jwtToken); __session_GWM5vUtE=\(jwtToken)"
        request.setValue(cookieString, forHTTPHeaderField: "Cookie")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status code
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadURLs = try decoder.decode([UploadURLResponse].self, from: data)
        
        return uploadURLs
    }
    


    static func uploadFileToPresignedURL(uploadURL: String, filePath: String) async throws -> UploadResponse {
        // Create URL
        guard let url = URL(string: uploadURL) else {
            throw NSError(domain: "InvalidURL", code: 400, userInfo: nil)
        }
        
        // Get file data
        let fileURL = URL(fileURLWithPath: filePath)
        let fileData = try Data(contentsOf: fileURL)
        
        // Generate boundary string
        let boundary = "WebKitFormBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        // Create multipart form data
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"blob\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        
        // Set headers
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("\"macOS\"", forHTTPHeaderField: "sec-ch-ua-platform")
        request.setValue("\"Google Chrome\";v=\"137\", \"Chromium\";v=\"137\", \"Not/A)Brand\";v=\"24\"", forHTTPHeaderField: "sec-ch-ua")
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        request.setValue("?0", forHTTPHeaderField: "sec-ch-ua-mobile")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://pic.ping.gg", forHTTPHeaderField: "Origin")
        request.setValue("cross-site", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("https://pic.ping.gg/", forHTTPHeaderField: "Referer")
        request.setValue("en-GB,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status code
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let responseData = String(data: data, encoding: .utf8) ?? "No response data"
            throw NSError(
                domain: "HTTPError",
                code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                userInfo: ["responseBody": responseData]
            )
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
        
        return uploadResponse
    }
    
}
