import SwiftUI
import AVKit

struct TranscriptionView: View {
    let videoURL: URL
    let transcriptionURL: URL
    @State private var transcriptionResponses: [TranscriptionResponse] = []
    @State private var isVideoExpanded = false
    @State private var player: AVPlayer?
    @Namespace private var animation
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VideoPlayer(player: player)
                    .frame(height: isVideoExpanded ? geometry.size.height * 0.4 : 200)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .matchedGeometryEffect(id: "video", in: animation)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isVideoExpanded.toggle()
                        }
                    }
                    .padding(.bottom, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Transcription")
                            .font(.title)
                            .padding(.horizontal)
                            .matchedGeometryEffect(id: "title", in: animation)
                        
                        ForEach(transcriptionResponses.flatMap { $0.segments }, id: \.id) { segment in
                            VStack(alignment: .leading) {
                                Text(segment.text)
                                    .padding(.vertical, 2)
                                Text("[\(formatTime(segment.start)) - \(formatTime(segment.end))]")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Video Transcription")
        .onAppear {
            player = AVPlayer(url: videoURL)
            loadTranscription()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func loadTranscription() {
        do {
            let data = try Data(contentsOf: transcriptionURL)
            let decoder = JSONDecoder()
            transcriptionResponses = try decoder.decode([TranscriptionResponse].self, from: data)
        } catch {
            print("Error loading transcription: \(error)")
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct TranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TranscriptionView(
                videoURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                transcriptionURL: URL(string: "https://example.com/transcription.txt")!
            )
        }
    }
}
