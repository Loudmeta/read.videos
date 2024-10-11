import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @Binding var videoURL: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onChange(of: videoURL) { oldValue, newValue in
                player = AVPlayer(url: newValue)
            }
            .onDisappear {
                player?.pause()
            }
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        if let url = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4") {
            VideoPlayerView(videoURL: .constant(url))
        } else {
            Text("Preview unavailable")
        }
    }
}
