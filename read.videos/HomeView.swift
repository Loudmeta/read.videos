import SwiftUI
import PhotosUI
import AVFoundation

struct HomeView: View {
    @State private var selectedVideo: URL?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var transcribedVideos: [TranscribedVideo] = []
    @State private var isShowingURLInput = false
    @State private var videoURL = ""
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Transcribed Videos")) {
                    ForEach(transcribedVideos) { video in
                        NavigationLink(destination: TranscriptionView(videoURL: video.videoURL, transcriptionURL: video.transcriptionURL)) {
                            VStack(alignment: .leading) {
                                Text(video.fileName)
                                Text(video.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteTranscribedVideos)
                }
                
                Section {
                    PhotosPicker(selection: $photoPickerItem, matching: .videos) {
                        Label("Import Video from Device", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { isShowingURLInput = true }) {
                        Label("Import Video from URL", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Read.Videos")
            .toolbar {
                EditButton()
            }
            .onChange(of: photoPickerItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let url = saveVideoToDocuments(data: data) {
                            selectedVideo = url
                            await transcribeVideo(url: url)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingURLInput) {
                URLInputView(videoURL: $videoURL, isPresented: $isShowingURLInput, onSubmit: importVideoFromURL)
            }
            .overlay(
                Group {
                    if isDownloading {
                        VStack {
                            ProgressView("Downloading video...", value: downloadProgress, total: 1.0)
                            Button("Cancel") {
                                // Implement cancel functionality
                                isDownloading = false
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                    }
                }
            )
        }
        .onAppear {
            loadTranscribedVideos()
        }
    }
    
    private func importVideoFromURL() {
        guard let url = URL(string: videoURL) else {
            print("Invalid URL")
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        // Basic URL parsing logic
        let parsedURL = parseVideoURL(url)
        downloadAndPrepareVideo(from: parsedURL)
    }
    
    private func parseVideoURL(_ url: URL) -> URL {
        // Basic parsing logic - can be extended for different platforms
        if url.host?.contains("youtube.com") == true {
            // Extract YouTube video ID and construct direct link
            if let videoID = url.query?.components(separatedBy: "v=").last {
                return URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
            }
        }
        // Add more platform-specific parsing here
        
        // If no specific parsing is done, return the original URL
        return url
    }
    
    private func downloadAndPrepareVideo(from url: URL) {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
                return
            }
            
            guard let localURL = localURL else {
                print("Local URL is nil")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: localURL, to: destination)
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.selectedVideo = destination
                    Task {
                        await self.transcribeVideo(url: destination)
                    }
                }
            } catch {
                print("File error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
            }
        }
        
        downloadTask.resume()
        
        // Update progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let progress = Double(downloadTask.countOfBytesReceived) / Double(downloadTask.countOfBytesExpectedToReceive)
            DispatchQueue.main.async {
                self.downloadProgress = min(max(progress, 0.0), 1.0)
                if progress >= 1.0 || !self.isDownloading {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func saveVideoToDocuments(data: Data) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "imported_video_\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }
    
    private func transcribeVideo(url: URL) async {
        do {
            let transcriptionURL = try await APIService.shared.transcribeVideoInRealTime(url: url)
            let newVideo = TranscribedVideo(id: UUID(), videoURL: url, transcriptionURL: transcriptionURL, createdAt: Date())
            transcribedVideos.append(newVideo)
            saveTranscribedVideos()
        } catch {
            print("Error transcribing video: \(error)")
        }
    }
    
    private func loadTranscribedVideos() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transcribedVideosURL = documentsDirectory.appendingPathComponent("transcribedVideos.json")
        
        if let data = try? Data(contentsOf: transcribedVideosURL) {
            if let decodedVideos = try? JSONDecoder().decode([TranscribedVideo].self, from: data) {
                transcribedVideos = decodedVideos
            }
        }
    }
    
    private func saveTranscribedVideos() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transcribedVideosURL = documentsDirectory.appendingPathComponent("transcribedVideos.json")
        
        if let encodedData = try? JSONEncoder().encode(transcribedVideos) {
            try? encodedData.write(to: transcribedVideosURL)
        }
    }
    
    private func deleteTranscribedVideos(at offsets: IndexSet) {
        let videosToDelete = offsets.map { transcribedVideos[$0] }
        
        for video in videosToDelete {
            // Delete the video file
            try? FileManager.default.removeItem(at: video.videoURL)
            
            // Delete the transcription file
            try? FileManager.default.removeItem(at: video.transcriptionURL)
        }
        
        transcribedVideos.remove(atOffsets: offsets)
        saveTranscribedVideos()
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedURL = url
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

struct URLInputView: View {
    @Binding var videoURL: String
    @Binding var isPresented: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter Video URL")) {
                    TextField("https://example.com/video.mp4", text: $videoURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Button("Import") {
                    onSubmit()
                    isPresented = false
                }
                .disabled(videoURL.isEmpty)
            }
            .navigationTitle("Import from URL")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}