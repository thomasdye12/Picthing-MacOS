//
//  ActionRequestHandler.swift
//  PicThing Thumbnail
//
//  Created by Thomas Dye on 14/07/2025.
//

import Foundation
import Cocoa

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    
    // Log collection
    private var logEntries: [String] = ["Process started at \(Date())"]
    
    func beginRequest(with context: NSExtensionContext) {
        logEntries.append("Beginning request")
        
        // Get credentials from UserDefaults
        let credentials = getClientToken()
        let sessionID = credentials.1
        let clientToken = credentials.0
        
        logEntries.append("Retrieved credentials - Session ID length: \(sessionID.count), Client token length: \(clientToken.count)")
        

        
        // For an Action Extension there will only ever be one extension item.
        precondition(context.inputItems.count == 1)
        guard let inputItem = context.inputItems[0] as? NSExtensionItem
        else {
            logEntries.append("Failed: Expected an extension item")
            createErrorLog("Expected an extension item but didn't get one")
            completeRequestWithError(context, "Invalid extension item", outputAttachments: [])
            return
        }
        
        // The extension item's attachments hold the set of files to process.
        guard let inputAttachments = inputItem.attachments
        else {
            logEntries.append("Failed: Expected valid attachments")
            createErrorLog("Expected valid attachments but didn't get any")
            completeRequestWithError(context, "No attachments found", outputAttachments: [])
            return
        }
        
        // The output will contain processed images
        var outputAttachments = inputAttachments
        
        
        precondition(inputAttachments.isEmpty == false, "Expected at least one attachment")
        if inputAttachments.isEmpty {
            logEntries.append("Failed: No attachments to process")
            createErrorLog("No attachments to process")
            completeRequestWithError(context, "No attachments to process", outputAttachments: outputAttachments)
            return
        }
        
        logEntries.append("Found \(inputAttachments.count) attachments to process")
        
        // Validate credentials
        if clientToken.isEmpty || sessionID.isEmpty {
            createErrorLog("Missing credentials. Client token or Session ID is empty.")
            completeRequestWithError(context, "Authentication credentials are missing", outputAttachments: outputAttachments)
            return
        }
        

        // Use a dispatch group to synchronize asynchronous calls
        let dispatchGroup = DispatchGroup()
        
        // Create a Task for async work
        Task {
            do {
                // Get JWT token once for all files
                logEntries.append("Fetching Clerk JWT token")
                let jwtToken: String
                
                do {
                    // Since we don't see the clerk class, we'll have to implement fetchClerkToken here
                    jwtToken = try await clerk.fetchClerkToken(clientToken: clientToken, sessionID: sessionID)
                    logEntries.append("Successfully obtained JWT token of length: \(jwtToken.count)")
                } catch {
                    logEntries.append("Failed to fetch JWT token: \(error)")
                    createErrorLog("Failed to fetch JWT token: \(error)")
                    completeRequestWithError(context, "Authentication failed", outputAttachments: outputAttachments)
                    return
                }
                
                for (index, attachment) in inputAttachments.enumerated() {
                    dispatchGroup.enter()
                    logEntries.append("Processing attachment \(index+1)")
                    
                    // Load each file and upload it
                    attachment.loadInPlaceFileRepresentation(forTypeIdentifier: "public.image") { [weak self] (url, inPlace, error) in
                        guard let self = self else {
                            self?.logEntries.append("Self was deallocated during processing")
                            dispatchGroup.leave()
                            return
                        }
                        
                        // If an image can be loaded from the URL, upload it
                        if let sourceUrl = url {
                            self.logEntries.append("Loaded file from: \(sourceUrl.path)")
                            
                            Task {
                                do {
                                    // Get file attributes
                                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: sourceUrl.path)
                                    let fileSize = fileAttributes[.size] as? Int ?? 0
                                    let fileType = sourceUrl.pathExtension.lowercased() == "heic" ? "image/heic" : "image/jpeg"
                                    
                                    self.logEntries.append("File size: \(fileSize) bytes, type: \(fileType)")
                                    
                                    // Create file info
                                    let fileInfo = FileInfo(
                                        name: sourceUrl.lastPathComponent,
                                        size: fileSize,
                                        type: fileType,
                                        lastModified: Int(Date().timeIntervalSince1970 * 1000)
                                    )
                                    
                                    // Initiate upload
                                    self.logEntries.append("Initiating upload for file: \(sourceUrl.lastPathComponent)")
                                    let uploadURLs: [UploadURLResponse]
                                    
                                    do {
                                        // Since we don't see the UploadThing class, implement initiateUploadThing here
                                        uploadURLs = try await UploadThing.initiateUploadThing(jwtToken: jwtToken, sessionID: sessionID, files: [fileInfo])
                                        self.logEntries.append("Received upload URL: \(uploadURLs[0].url)")
                                    } catch {
                                        self.logEntries.append("Failed to get upload URL: \(error)")
                                        self.createErrorLog("Failed to get upload URL: \(error)")
                                        dispatchGroup.leave()
                                        return
                                    }
                                    
                                    // Upload the file
                                    self.logEntries.append("Uploading file to presigned URL")
                                    let uploadResponse: UploadResponse
                                    
                                    do {
                                        // Implement uploadFileToPresignedURL here
                                        uploadResponse = try await UploadThing.uploadFileToPresignedURL(
                                            uploadURL: uploadURLs[0].url,
                                            filePath: sourceUrl.path
                                        )
                                        self.logEntries.append("File uploaded successfully to: \(uploadResponse.url)")
                                    } catch {
                                        self.logEntries.append("Failed to upload file: \(error)")
                                        self.createErrorLog("Failed to upload file: \(error)")
                                        dispatchGroup.leave()
                                        return
                                    }
                                    
                                    // Download the background-removed image
                                    self.logEntries.append("Downloading background-removed image")
                                    let bgRemovalURL = "https://bg.image.engineering/?image=" + uploadResponse.appUrl
                                    
                                    do {
                                        let processedImageData = try await self.downloadImage(from: bgRemovalURL)
                                        self.logEntries.append("Downloaded processed image: \(processedImageData.count) bytes")
                                        
                                        // Create a provider for the processed image
                                        let processedItemProvider = self.createProcessedImageFile(
                                            sourceUrl: sourceUrl,
                                            imageData: processedImageData
                                        )
                                        
                                        // Add to output
                                        DispatchQueue.main.async {
                                            self.logEntries.append("Adding processed image to output attachments")
                                            outputAttachments.append(processedItemProvider)
                                            dispatchGroup.leave()
                                        }
                                    } catch {
                                        self.logEntries.append("Failed to download or process image: \(error)")
                                        self.createErrorLog("Failed to download or process image: \(error)")
                                        
                                        // Create error text file instead
                                        let errorProvider = self.createErrorFile(
                                            sourceUrl: sourceUrl,
                                            error: error,
                                            uploadResponse: uploadResponse
                                        )
                                        
                                        DispatchQueue.main.async {
                                            outputAttachments.append(errorProvider)
                                            dispatchGroup.leave()
                                        }
                                    }
                                } catch {
                                    self.logEntries.append("Error in file processing: \(error)")
                                    self.createErrorLog("Error in file processing: \(error)")
                                    dispatchGroup.leave()
                                }
                            }
                        } else if let error = error {
                            self.logEntries.append("Error loading file: \(error)")
                            self.createErrorLog("Error loading file: \(error)")
                            dispatchGroup.leave()
                        } else {
                            self.logEntries.append("Expected either a valid URL or an error.")
                            self.createErrorLog("Expected either a valid URL or an error.")
                            dispatchGroup.leave()
                        }
                    }
                }
                
                dispatchGroup.notify(queue: DispatchQueue.main) {
                    self.logEntries.append("All tasks completed, preparing to return results")
                    
                    if outputAttachments.isEmpty {
                        self.logEntries.append("No output attachments were created")
                        let errorLogProvider = self.createFullLogFile()
                        outputAttachments.append(errorLogProvider)
                    }
                    
                    let outputItem = NSExtensionItem()
                    outputItem.attachments = outputAttachments
                    self.logEntries.append("Completing request with \(outputAttachments.count) attachments")
                    context.completeRequest(returningItems: [outputItem], completionHandler: nil)
                }
            } catch {
                logEntries.append("Unhandled error in main task: \(error)")
                createErrorLog("Unhandled error in main task: \(error)")
                
                // Complete the request with an error log
                completeRequestWithError(context, "Processing failed: \(error)", outputAttachments: outputAttachments)
            }
        }
    }
    
    // Helper method to complete request with error
    private func completeRequestWithError(_ context: NSExtensionContext, _ message: String,outputAttachments:[NSItemProvider]) {
        let errorLogProvider = createFullLogFile(withError: message)
        let outputItem = NSExtensionItem()
        var items = [NSItemProvider]()
        items = outputAttachments
        items.append(errorLogProvider)
        outputItem.attachments = items

        context.completeRequest(returningItems: [outputItem], completionHandler: nil)
    }
    
    // Create a text file with the full log
    func createFullLogFile(withError errorMessage: String? = nil) -> NSItemProvider {
        let itemProvider = NSItemProvider()
        
        if let error = errorMessage {
            logEntries.append("ERROR: \(error)")
        }
        
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: kUTTypePlainText as String, fileOptions: [.openInPlace],
            visibility: .all, loadHandler: { completionHandler in
                let logContent = self.logEntries.joined(separator: "\n")
                let logUrl = self.getLogFileUrl()
                try? logContent.write(to: logUrl, atomically: true, encoding: .utf8)
                completionHandler(logUrl, false, nil)
                return nil
            }
        )
        return itemProvider
    }
    
    // Create an error log text file
    func createErrorLog(_ message: String) {
        logEntries.append("ERROR: \(message)")
        let logContent = logEntries.joined(separator: "\n")
        let logUrl = getLogFileUrl()
        try? logContent.write(to: logUrl, atomically: true, encoding: .utf8)
    }
    
    // Create an error file to return to the user
    func createErrorFile(sourceUrl: URL, error: Error, uploadResponse: UploadResponse? = nil) -> NSItemProvider {
        let itemProvider = NSItemProvider()
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: kUTTypePlainText as String, fileOptions: [.openInPlace],
            visibility: .all, loadHandler: { completionHandler in
                var errorText = "Error processing: \(sourceUrl.lastPathComponent)\n"
                errorText += "Error: \(error)\n\n"
                errorText += "Log:\n"
                errorText += self.logEntries.joined(separator: "\n")
                
                if let response = uploadResponse {
                    errorText += "\n\nImage was uploaded successfully but couldn't be processed:\n"
                    errorText += "Uploaded URL: \(response.url)\n"
                    errorText += "App URL: \(response.appUrl)\n"
                    errorText += "You can try to manually open: https://bg.image.engineering/?image=\(response.appUrl)"
                }
                
                let errorUrl = self.getErrorFileUrl(for: sourceUrl)
                try? errorText.write(to: errorUrl, atomically: true, encoding: .utf8)
                completionHandler(errorUrl, false, nil)
                return nil
            }
        )
        return itemProvider
    }
    
    func getLogFileUrl() -> URL {
        do {
            let itemReplacementDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: NSHomeDirectory()), create: true)
            let timestamp = Int(Date().timeIntervalSince1970)
            let logFilename = "bg_remover_log_\(timestamp).txt"
            return itemReplacementDirectory.appendingPathComponent(logFilename)
        } catch {
            logEntries.append("Error creating log file URL: \(error)")
            // Fallback
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bg_remover_log.txt")
        }
    }
    
    func getErrorFileUrl(for sourceUrl: URL) -> URL {
        do {
            let itemReplacementDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: NSHomeDirectory()), create: true)
            let errorFilename = sourceUrl.deletingPathExtension().lastPathComponent + "_error.txt"
            return itemReplacementDirectory.appendingPathComponent(errorFilename)
        } catch {
            logEntries.append("Error creating error file URL: \(error)")
            // Fallback
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("error.txt")
        }
    }
    // Download image from URL
       func downloadImage(from urlString: String) async throws -> Data {
           guard let url = URL(string: urlString) else {
               throw NSError(domain: "InvalidURL", code: 400, userInfo: nil)
           }
           
           let (data, response) = try await URLSession.shared.data(from: url)
           
           guard let httpResponse = response as? HTTPURLResponse,
                 httpResponse.statusCode == 200 else {
               throw NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: nil)
           }
           
           return data
       }
    
    // Create an NSItemProvider for the processed image
    func createProcessedImageFile(sourceUrl: URL, imageData: Data) -> NSItemProvider {
        let itemProvider = NSItemProvider()
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: kUTTypePNG as String, fileOptions: [.openInPlace],
            visibility: .all, loadHandler: { completionHandler in
                // Create a PNG file with the processed image
                let processedImageUrl = self.getProcessedImageUrl(for: sourceUrl)
                
                do {
                    try imageData.write(to: processedImageUrl)
                } catch {
                    print("Error saving processed image: \(error)")
                }
                
                completionHandler(processedImageUrl, false, nil)
                return nil
            }
        )
        return itemProvider
    }
    
    // Get URL for the processed image file
    func getProcessedImageUrl(for sourceUrl: URL) -> URL {
        do {
            let itemReplacementDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: NSHomeDirectory()), create: true)
            let processedFilename = sourceUrl.deletingPathExtension().lastPathComponent + "_nobg.png"
            return itemReplacementDirectory.appendingPathComponent(processedFilename)
        } catch {
            print(error)
            preconditionFailure()
        }
    }
    
    func createUploadedFile(sourceUrl: URL, uploadResponse: UploadResponse) -> NSItemProvider {
        let itemProvider = NSItemProvider()
        itemProvider.registerFileRepresentation(
            forTypeIdentifier: kUTTypePNG as String, fileOptions: [.openInPlace],
            visibility: .all, loadHandler: { completionHandler in
                // Create a text file with the upload info
                let uploadInfoText = """
                Original file: \(sourceUrl.lastPathComponent)
                Uploaded URL: \(uploadResponse.url)
                App URL: \(uploadResponse.appUrl)
                UFS URL: \(uploadResponse.ufsUrl)
                File Hash: \(uploadResponse.fileHash)
                """
                
                // Save the info to a file
                let infoUrl = self.getUploadInfoUrl(for: sourceUrl)
                try? uploadInfoText.write(to: infoUrl, atomically: true, encoding: .utf8)
                
                completionHandler(infoUrl, false, nil)
                return nil
            }
        )
        return itemProvider
    }
    
    func getUploadInfoUrl(for sourceUrl: URL) -> URL {
        do {
            let itemReplacementDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory, in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: NSHomeDirectory()), create: true)
            let infoFilename = sourceUrl.deletingPathExtension().lastPathComponent + "_upload_info.txt"
            return itemReplacementDirectory.appendingPathComponent(infoFilename)
        } catch {
            print(error)
            preconditionFailure()
        }
    }
    
    
    
    func getClientToken() -> (String,String) {
        // Replace with your actual App Group identifier
        // This must match your provisioning profile and any extension's identifier
        let appGroupID = "group.PicThingExtention"
        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            //             userDefaults.set(SessionID, forKey: "SessionID")
            return (userDefaults.string(forKey: "jwtToken") ?? "",userDefaults.string(forKey: "SessionID") ?? "")
        } else {
            return ("","")
        }

    }
}

extension NSImage {

    public var thumbnailImage: NSImage {
        let maxDimension: CGFloat = 320
        let aspectRatio = size.width / size.height
        let thumbnailWidth = (size.width > size.height) ? maxDimension : maxDimension * aspectRatio
        let thumbnailHeight = (size.width > size.height) ? maxDimension / aspectRatio: maxDimension
        let thumbnailSize = NSSize(width: thumbnailWidth, height: thumbnailHeight)
        return NSImage(size: thumbnailSize, flipped: false, drawingHandler: { [unowned self] (rect) -> Bool in
            self.draw(in: rect)
            return true
        })
    }

}


extension NSImage {

    func savePNGToDisk(at url: URL) {
        if let tiffData = self.tiffRepresentation,
            let bitmapImageRep = NSBitmapImageRep(data: tiffData),
            let pngData = bitmapImageRep.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: url)
            } catch {
                print(error)
            }
        }
    }

}


