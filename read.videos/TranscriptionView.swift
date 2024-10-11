import SwiftUI
import AVKit

struct TranscriptionView: View {
    let videoURL: URL
    let transcriptionURL: URL
    @State private var transcriptionText: AttributedString = AttributedString("")
    
    var body: some View {
        VStack {
            // Video Player
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 200)  // Adjust the height as needed
            
            // Transcription Text
            ScrollView {
                RichTextEditor(text: $transcriptionText)
                    .padding()
            }
        }
        .navigationTitle("Transcription")
        .onAppear {
            loadTranscription()
        }
    }
    
    private func loadTranscription() {
        do {
            let string = try String(contentsOf: transcriptionURL, encoding: .utf8)
            transcriptionText = AttributedString(string)
        } catch {
            print("Error loading transcription: \(error)")
            transcriptionText = AttributedString("Error loading transcription.")
        }
    }
}

struct TranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionView(
            videoURL: URL(string: "https://example.com/video.mp4")!,
            transcriptionURL: URL(string: "https://example.com/transcription.txt")!
        )
    }
}
