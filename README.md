# Read.Videos

Read.Videos is an innovative iOS application that transforms video content into easily digestible text formats. By leveraging advanced AI technologies, it provides transcriptions, summaries, and topic analyses of your videos, making content more accessible and manageable.

## About the App

Read.Videos allows users to import videos from their device or via URL, automatically transcribing the content and generating insightful summaries and topic breakdowns. This app is perfect for content creators, students, professionals, or anyone looking to efficiently extract and understand information from video content.

## Key Features

### 1. Video Import and Transcription
![Video Import](path/to/video_import.png)
- Import videos from your device or via URL
- Automatic transcription with timestamps

### 2. AI-Powered Summaries
![Summary Generation](path/to/summary.png)
- Generate concise summaries of video content
- Extract key points and insights

### 3. Topic Analysis
![Topic Analysis](path/to/topics.png)
- Identify main topics discussed in the video
- Provide timestamp ranges for each topic

### 4. User-Friendly Interface
![User Interface](path/to/ui.png)
- Intuitive grid layout for easy video management
- Tabbed interface for transcriptions, summaries, and topics

### 5. Copy and Share
![Copy Feature](path/to/copy_feature.png)
- Easy-to-use copy functionality for all generated content
- Share insights with just a tap

## Setting Up API Keys

To use Read.Videos, you'll need to set up API keys for the transcription and AI services. Follow these steps:

1. Create a file named `APIKeys.swift` in the project.
2. Add the following content to the file:

```
import Foundation

enum APIKeys {
    static let groqKey = "GROQ_API_KEY"
    static let openRouterKey = "OPENROUTER_API_KEY"
}

```
