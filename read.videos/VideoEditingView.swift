import SwiftUI
import PhotosUI

struct VideoEditingView: View {
    @State private var selectedVideo: URL?
    @State private var photoPickerItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack {
                if let videoURL = selectedVideo {
                    VideoPlayerView(videoURL: .constant(videoURL))
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                    
                    // Placeholder for video editing controls
                    Text("Video Editing Controls")
                        .font(.headline)
                        .padding()
                    
                    // Placeholder for timeline
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 50)
                        .cornerRadius(10)
                        .padding()
                    
                    // Placeholder for editing options
                    HStack {
                        ForEach(["Cut", "Trim", "Split", "Effects"], id: \.self) { option in
                            Button(action: {}) {
                                Text(option)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                } else {
                    Text("Select a video to edit")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Video Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photoPickerItem, matching: .videos) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: photoPickerItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let url = saveVideoToDocuments(data: data) {
                            selectedVideo = url
                        }
                    }
                }
            }
        }
    }
    
    private func saveVideoToDocuments(data: Data) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileName = "imported_video_\(Date().timeIntervalSince1970).mov"
        guard let fileURL = documentsDirectory?.appendingPathComponent(fileName) else { return nil }
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }
}

struct VideoEditingView_Previews: PreviewProvider {
    static var previews: some View {
        VideoEditingView()
    }
}
