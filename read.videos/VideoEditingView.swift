import SwiftUI
import PhotosUI
import AVFoundation

struct VideoEditingView: View {
    @State private var selectedVideo: URL?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: IdentifiableError?
    
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
                    await importVideo(from: newValue)
                }
            }
            .overlay(
                Group {
                    if isImporting {
                        ProgressView("Importing video...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                    }
                }
            )
            .alert(item: $importError) { error in
                Alert(title: Text("Import Error"), message: Text(error.error), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func importVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isImporting = true
        defer { isImporting = false }
        
        do {
            guard let videoData = try await item.loadTransferable(type: Data.self) else {
                importError = IdentifiableError(error: "Failed to load video data")
                return
            }
            
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileName = "editing_video_\(Date().timeIntervalSince1970).mov"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try videoData.write(to: fileURL)
            
            selectedVideo = fileURL
            // You may want to add transcription functionality here if needed
        } catch {
            importError = IdentifiableError(error: "Error importing video: \(error.localizedDescription)")
        }
    }
}

struct VideoEditingView_Previews: PreviewProvider {
    static var previews: some View {
        VideoEditingView()
    }
}
