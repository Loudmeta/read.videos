import Foundation

struct TranscriptionData: Codable {
    struct Segment: Codable {
        let timestamp: String
        let text: String
    }
    
    let segments: [Segment]
    var summary: String
    var topics: String
    
    enum CodingKeys: String, CodingKey {
        case segments
        case summary
        case topics
    }
    
    init(segments: [Segment], summary: String, topics: String = "") {
        self.segments = segments
        self.summary = summary
        self.topics = topics
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let segmentsArray = try? container.decode([Segment].self, forKey: .segments) {
            segments = segmentsArray
        } else if let segmentsDictionary = try? container.decode([String: String].self, forKey: .segments) {
            segments = segmentsDictionary.map { Segment(timestamp: $0.key, text: $0.value) }
        } else {
            segments = []
        }
        
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        topics = try container.decodeIfPresent(String.self, forKey: .topics) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(segments, forKey: .segments)
        try container.encode(summary, forKey: .summary)
        try container.encode(topics, forKey: .topics)
    }
}
