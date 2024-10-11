import Foundation

struct SmallModelAPI {
    static let shared = SmallModelAPI()
    private let siteURL = "https://read.videos"
    private let siteName = "Read.Videos"
    
    private init() {}
    
    func generateSummary(from transcription: String) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKeys.openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue(siteURL, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(siteName, forHTTPHeaderField: "X-Title")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let message = """
        Analyze and summarize the following transcription extensively. Provide a rich, detailed summary in a single paragraph, followed by a small section with personal comments or insights.

        It is VERY IMPORTANT to format the output in markdown, strictly adhering to the following structure:


        [Your single-paragraph summary goes here]

        ## Comments

        - [First comment or insight]
        - [Second comment or insight]
        - [Third comment or insight]

        Transcription:
        \(transcription)
        """
        
        let body: [String: Any] = [
            "model": "meta-llama/llama-3.2-1b-instruct:free",
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SmallModelResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Failed to generate summary."
    }
    
    func generateTopics(from transcription: String) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKeys.openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue(siteURL, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(siteName, forHTTPHeaderField: "X-Title")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let message = """
        Analyze the following transcription and identify the main overarching topics discussed. Focus on broad, general themes rather than specific details. Aim to provide 3-5 major topics that encompass the entire content. For each topic, provide a concise description and the relevant timestamp range. Format the output in markdown, strictly adhering to the following structure:

        # Main Topics

        ## [Broad Topic 1]
        - Timestamp Range: [Start time] - [End time]
        - Overview: [Concise description of the broad topic and its significance in the overall discussion]

        ## [Broad Topic 2]
        - Timestamp Range: [Start time] - [End time]
        - Overview: [Concise description of the broad topic and its significance in the overall discussion]

        (Continue for all identified broad topics, aiming for 3-5 in total)

        Remember to focus on overarching themes that capture the essence of the entire transcription, rather than listing many specific subtopics.

        Transcription:
        \(transcription)
        """
        
        let body: [String: Any] = [
            "model": "meta-llama/llama-3.2-1b-instruct:free",
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SmallModelResponse.self, from: data)
        
        return response.choices.first?.message.content ?? "Failed to generate topics."
    }
}

struct SmallModelResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}
