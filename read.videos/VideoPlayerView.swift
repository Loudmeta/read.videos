import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @Binding var videoURL: URL?
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
            } else {
                Text("No video loaded")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .onChange(of: videoURL) { oldValue, newValue in
            if let url = newValue {
                player = AVPlayer(url: url)
            } else {
                player = nil
            }
        }
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(videoURL: .constant(URL(string: "https://example.com/sample-video.mp4")))
    }
}
