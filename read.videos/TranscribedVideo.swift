import Foundation

struct TranscribedVideo: Identifiable, Codable {
    let id: UUID
    let videoURL: URL
    let transcriptionURL: URL
    let createdAt: Date
    
    var fileName: String {
        videoURL.lastPathComponent
    }
}