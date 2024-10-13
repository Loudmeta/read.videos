import Foundation
import AVFoundation
import Combine
import os

struct TranscriptionSegment: Codable {
    let id: Int
    let seek: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]
    let temperature: Double
    let avg_logprob: Double
    let compression_ratio: Double
    let no_speech_prob: Double
}

struct TranscriptionResponse: Codable {
    let task: String
    let language: String
    let duration: Double
    let segments: [TranscriptionSegment]
    let text: String
}

@Observable class APIService {
    static let shared = APIService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "APIService")
    
    private init() {}
    
    func processVideo(url: URL) async throws -> TranscribedVideo {
        logger.info("Starting video processing for: \(url.lastPathComponent)")
        let audioURL = try await extractAudioFromVideo(url: url)
        logger.info("Audio extracted successfully: \(audioURL.lastPathComponent)")
        let transcriptionResponses = try await transcribeAudioInChunks(audioURL: audioURL)
        logger.info("Transcription completed with \(transcriptionResponses.count) chunks")
        let transcriptionURL = try await saveTranscription(transcriptionResponses, for: url)
        logger.info("Transcription saved to: \(transcriptionURL.lastPathComponent)")
        
        let transcriptionData = try await loadTranscriptionData(from: transcriptionURL)
        logger.info("Transcription data loaded successfully")
        let summary = try await generateSummary(from: transcriptionData)
        logger.info("Summary generated successfully")
        let topics = try await generateTopics(from: transcriptionData)
        logger.info("Topics generated successfully")
        
        let updatedTranscriptionData = TranscriptionData(
            segments: transcriptionData.segments,
            summary: summary,
            topics: topics
        )
        
        try await saveTranscriptionData(updatedTranscriptionData, for: url)
        logger.info("Updated transcription data saved successfully")
        
        return TranscribedVideo(
            id: UUID(),
            videoURL: url,
            transcriptionURL: transcriptionURL,
            fileName: url.lastPathComponent,
            createdAt: Date()
        )
    }
    
    private func extractAudioFromVideo(url: URL) async throws -> URL {
        logger.info("Extracting audio from video: \(url.lastPathComponent)")
        let asset = AVURLAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            logger.error("Failed to create export session")
            throw NSError(domain: "APIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioTimePitchAlgorithm = .spectral
        
        do {
            try await exportSession.export()
            
            if let error = exportSession.error {
                logger.error("Error during audio export: \(error.localizedDescription)")
                throw error
            }
            
            logger.info("Audio extracted successfully: \(outputURL.lastPathComponent)")
            return outputURL
        } catch {
            logger.error("Failed to export audio: \(error.localizedDescription)")
            throw NSError(domain: "APIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to export audio: \(error.localizedDescription)"])
        }
    }
    
    private func transcribeAudioInChunks(audioURL: URL) async throws -> [TranscriptionResponse] {
        logger.info("Starting audio transcription in chunks: \(audioURL.lastPathComponent)")
        let audioData = try Data(contentsOf: audioURL)
        let chunkSize = 20 * 1024 * 1024 // 20MB in bytes
        var transcriptionResponses: [TranscriptionResponse] = []
        
        for chunkStart in stride(from: 0, to: audioData.count, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, audioData.count)
            let audioChunk = audioData[chunkStart..<chunkEnd]
            
            logger.info("Transcribing chunk \(transcriptionResponses.count + 1) (size: \(audioChunk.count) bytes)")
            
            do {
                let response = try await transcribeAudioChunk(audioChunk)
                transcriptionResponses.append(response)
                logger.info("Chunk \(transcriptionResponses.count) transcribed successfully")
            } catch {
                logger.error("Error transcribing chunk \(transcriptionResponses.count + 1): \(error.localizedDescription)")
                throw error
            }
        }
        
        logger.info("All chunks transcribed successfully. Total chunks: \(transcriptionResponses.count)")
        return transcriptionResponses
    }
    
    private func transcribeAudioChunk(_ audioData: Data) async throws -> TranscriptionResponse {
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
        body.append("whisper-large-v3-turbo".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add the response_format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
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
        
        let decoder = JSONDecoder()
        let transcriptionResponse = try decoder.decode(TranscriptionResponse.self, from: data)
        
        logger.info("Successfully transcribed chunk")
        return transcriptionResponse
    }
    
    private func saveTranscription(_ transcription: [TranscriptionResponse], for videoURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let transcriptionURL = documentsDirectory.appendingPathComponent("\(videoURL.deletingPathExtension().lastPathComponent)_transcription.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(transcription)
        try jsonData.write(to: transcriptionURL)
        
        return transcriptionURL
    }
    
    private func loadTranscriptionData(from url: URL) async throws -> TranscriptionData {
        let data = try Data(contentsOf: url)
        let transcriptionResponses = try JSONDecoder().decode([TranscriptionResponse].self, from: data)
        
        let segments = transcriptionResponses.flatMap { response in
            response.segments.map { segment in
                TranscriptionData.Segment(timestamp: "\(formatTime(segment.start)) - \(formatTime(segment.end))", text: segment.text)
            }
        }
        
        return TranscriptionData(segments: segments, summary: "", topics: "")
    }
    
    private func generateSummary(from transcriptionData: TranscriptionData) async throws -> String {
        let fullTranscription = transcriptionData.segments.map { $0.text }.joined(separator: " ")
        return try await SmallModelAPI.shared.generateSummary(from: fullTranscription)
    }
    
    private func generateTopics(from transcriptionData: TranscriptionData) async throws -> String {
        let fullTranscription = transcriptionData.segments.map { "\($0.timestamp): \($0.text)" }.joined(separator: "\n")
        return try await SmallModelAPI.shared.generateTopics(from: fullTranscription)
    }
    
    private func saveTranscriptionData(_ transcriptionData: TranscriptionData, for videoURL: URL) async throws {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let transcriptionURL = documentsDirectory.appendingPathComponent("\(videoURL.deletingPathExtension().lastPathComponent)_transcription.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(transcriptionData)
        try jsonData.write(to: transcriptionURL)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}