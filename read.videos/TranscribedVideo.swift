import Foundation

struct TranscribedVideo: Identifiable, Codable {
    let id: UUID
    let videoURL: URL
    let transcriptionURL: URL
    let fileName: String
    let createdAt: Date
}