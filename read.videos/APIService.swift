import Foundation
import AVFoundation
import Combine
import os

@Observable class APIService {
    static let shared = APIService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "APIService")
    
    private init() {}
    
    func transcribeVideoInRealTime(url: URL) async throws -> URL {
        let transcription = try await AsyncThrowingStream { continuation in
            Task {
                do {
                    logger.info("Starting transcription for video: \(url.lastPathComponent)")
                    let audioURL = try await extractAudioFromVideo(url: url)
                    let audioData = try Data(contentsOf: audioURL)
                    
                    let chunkSize = 25 * 1024 * 1024 // 25MB in bytes
                    var chunkCount = 0
                    
                    for chunk in stride(from: 0, to: audioData.count, by: chunkSize) {
                        let end = min(chunk + chunkSize, audioData.count)
                        let audioChunk = audioData[chunk..<end]
                        
                        chunkCount += 1
                        logger.info("Transcribing chunk \(chunkCount) (size: \(audioChunk.count) bytes)")
                        
                        do {
                            let transcription = try await self.transcribeAudioChunk(audioChunk)
                            continuation.yield(transcription)
                        } catch {
                            logger.error("Error transcribing chunk \(chunkCount): \(error.localizedDescription)")
                            continuation.yield("Error transcribing chunk \(chunkCount): \(error.localizedDescription)")
                        }
                    }
                    
                    logger.info("Transcription completed successfully")
                    continuation.finish()
                } catch {
                    logger.error("Transcription error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }.reduce(into: "") { $0 += $1 }
        
        return try await saveTranscription(transcription, for: url)
    }
    
    private func saveTranscription(_ transcription: String, for videoURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let transcriptionURL = documentsDirectory.appendingPathComponent("\(videoURL.deletingPathExtension().lastPathComponent)_transcription.txt")
        
        try transcription.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        
        return transcriptionURL
    }
    
    private func extractAudioFromVideo(url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "APIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .spectral
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            throw NSError(domain: "APIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed: \(error.localizedDescription)"])
        }
    }
    
    private func transcribeAudioChunk(_ audioData: Data) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKeys.groqKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add the audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"chunk.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add the model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("distil-whisper-large-v3-en".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Groq API")
                throw NSError(domain: "APIService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Groq API"])
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response body: \(responseString)")
                }
                throw NSError(domain: "APIService", code: 5, userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"])
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let text = json["text"] as? String else {
                logger.error("Unexpected JSON structure from Groq API")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response body: \(responseString)")
                }
                throw NSError(domain: "APIService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unexpected JSON structure"])
            }
            
            logger.info("Successfully transcribed chunk")
            return text
        } catch {
            logger.error("Error transcribing chunk: \(error.localizedDescription)")
            throw error
        }
    }
}