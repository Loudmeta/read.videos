import SwiftUI
import AVKit

struct TranscriptionView: View {
    let videoURL: URL
    let transcriptionURL: URL
    @State private var transcriptionText: String = ""
    @State private var isVideoExpanded = false
    @Namespace private var animation
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: isVideoExpanded ? geometry.size.height * 0.6 : 200)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                        .matchedGeometryEffect(id: "video", in: animation)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isVideoExpanded.toggle()
                            }
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Transcription")
                            .font(.title)
                            .padding(.horizontal)
                            .matchedGeometryEffect(id: "title", in: animation)
                        
                        Text(transcriptionText)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .matchedGeometryEffect(id: "transcription", in: animation)
                    }
                    .opacity(isVideoExpanded ? 0 : 1)
                    .animation(.easeInOut, value: isVideoExpanded)
                }
            }
        }
        .navigationTitle("Video Transcription")
        .onAppear {
            loadTranscription()
        }
    }
    
    private func loadTranscription() {
        do {
            transcriptionText = try String(contentsOf: transcriptionURL, encoding: .utf8)
        } catch {
            print("Error loading transcription: \(error)")
            transcriptionText = "Error loading transcription."
        }
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
