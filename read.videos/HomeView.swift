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
    @State private var isImporting = false
    @State private var importError: IdentifiableError?
    @State private var selectedTranscription: TranscribedVideo?
    @State private var isShowingImportOptions = false
    @State private var isSelectMode = false
    @State private var selectedItems: Set<UUID> = []
    @Namespace private var animation
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(PlaceholderTranscribedVideo.placeholders) { placeholder in
                            PlaceholderTranscriptionCard(placeholder: placeholder)
                        }
                        ForEach(transcribedVideos) { video in
                            TranscriptionCard(video: video, namespace: animation, isSelected: selectedItems.contains(video.id))
                                .onTapGesture {
                                    if isSelectMode {
                                        toggleSelection(for: video)
                                    } else {
                                        withAnimation(.spring()) {
                                            selectedTranscription = video
                                        }
                                    }
                                }
                                .onLongPressGesture {
                                    enterSelectMode(selecting: video)
                                }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Read.Videos")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectMode {
                            Button("Delete", action: deleteSelectedItems)
                                .foregroundColor(.red)
                        } else {
                            EditButton()
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isSelectMode {
                            Button("Cancel") {
                                exitSelectMode()
                            }
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ImportOptionsMenu(
                            isShowingImportOptions: $isShowingImportOptions,
                            photoPickerItem: $photoPickerItem,
                            isShowingURLInput: $isShowingURLInput
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .overlay {
                if let selected = selectedTranscription {
                    TranscriptionDetailView(video: selected, namespace: animation) {
                        withAnimation(.spring()) {
                            selectedTranscription = nil
                        }
                    }
                    .zIndex(1)
                }
            }
            .onChange(of: photoPickerItem) { oldValue, newValue in
                Task {
                    await importVideo(from: newValue)
                }
            }
            .sheet(isPresented: $isShowingURLInput) {
                URLInputView(videoURL: $videoURL, isPresented: $isShowingURLInput, onSubmit: importVideoFromURL)
            }
            .overlay {
                if isDownloading {
                    ProgressView("Downloading video...", value: downloadProgress, total: 1.0)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                } else if isImporting {
                    ProgressView("Importing video...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert(item: $importError) { error in
                Alert(title: Text("Import Error"), message: Text(error.error), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            loadTranscribedVideos()
        }
    }
    
    private func enterSelectMode(selecting video: TranscribedVideo) {
        isSelectMode = true
        selectedItems.insert(video.id)
    }
    
    private func exitSelectMode() {
        isSelectMode = false
        selectedItems.removeAll()
    }
    
    private func toggleSelection(for video: TranscribedVideo) {
        if selectedItems.contains(video.id) {
            selectedItems.remove(video.id)
        } else {
            selectedItems.insert(video.id)
        }
    }
    
    private func deleteSelectedItems() {
        transcribedVideos.removeAll { video in
            if selectedItems.contains(video.id) {
                // Delete the actual files
                try? FileManager.default.removeItem(at: video.videoURL)
                try? FileManager.default.removeItem(at: video.transcriptionURL)
                return true
            }
            return false
        }
        saveTranscribedVideos()
        exitSelectMode()
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
            let fileName = "imported_video_\(Date().timeIntervalSince1970).mov"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try videoData.write(to: fileURL)
            
            selectedVideo = fileURL
            await transcribeVideo(url: fileURL)
        } catch {
            importError = IdentifiableError(error: "Error importing video: \(error.localizedDescription)")
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
            let newVideo = TranscribedVideo(id: UUID(), videoURL: url, transcriptionURL: transcriptionURL, fileName: url.lastPathComponent, createdAt: Date())
            transcribedVideos.append(newVideo)
            saveTranscribedVideos()
        } catch {
            print("Error transcribing video: \(error)")
            importError = IdentifiableError(error: "Error transcribing video: \(error.localizedDescription)")
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

struct TranscriptionCard: View {
    let video: TranscribedVideo
    var namespace: Namespace.ID
    var isSelected: Bool
    @State private var transcriptionPreview: String = ""
    
    var body: some View {
        VStack {
            VideoPlayerView(videoURL: .constant(video.videoURL))
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .matchedGeometryEffect(id: "video\(video.id)", in: namespace)
                .overlay(
                    isSelected ?
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 3)
                    : nil
                )
            
            Text(video.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(transcriptionPreview)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150, height: 220)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
        .matchedGeometryEffect(id: "card\(video.id)", in: namespace)
        .onAppear {
            loadTranscriptionPreview()
        }
    }
    
    private func loadTranscriptionPreview() {
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: video.transcriptionURL)
                let decoder = JSONDecoder()
                let transcriptionResponses = try decoder.decode([TranscriptionResponse].self, from: data)
                let fullTranscription = transcriptionResponses.flatMap { $0.segments }.map { $0.text }.joined(separator: " ")
                let words = fullTranscription.split(separator: " ")
                let preview = words.prefix(10).joined(separator: " ") + (words.count > 10 ? "..." : "")
                DispatchQueue.main.async {
                    self.transcriptionPreview = preview
                }
            } catch {
                print("Error loading transcription preview: \(error)")
                DispatchQueue.main.async {
                    self.transcriptionPreview = "Error loading preview"
                }
            }
        }
    }
}

struct TranscriptionDetailView: View {
    let video: TranscribedVideo
    var namespace: Namespace.ID
    var onDismiss: () -> Void
    
    @State private var transcriptionResponses: [TranscriptionResponse] = []
    @State private var isLoading = true
    @State private var isVideoExpanded = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack {
                        VideoPlayerView(videoURL: .constant(video.videoURL))
                            .frame(height: isVideoExpanded ? geometry.size.height * 0.6 : 200)
                            .cornerRadius(15)
                            .shadow(radius: 10)
                            .matchedGeometryEffect(id: "video\(video.id)", in: namespace)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    isVideoExpanded.toggle()
                                }
                            }
                        
                        VStack(alignment: .leading) {
                            Text(video.fileName)
                                .font(.title)
                            Text(video.createdAt, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .opacity(isVideoExpanded ? 0 : 1)
                        .animation(.easeInOut, value: isVideoExpanded)
                        
                        if isLoading {
                            ProgressView("Loading transcription...")
                        } else {
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
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
                .matchedGeometryEffect(id: "card\(video.id)", in: namespace)
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadTranscription()
        }
    }
    
    private func loadTranscription() {
        isLoading = true
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: video.transcriptionURL)
                let decoder = JSONDecoder()
                let responses = try decoder.decode([TranscriptionResponse].self, from: data)
                DispatchQueue.main.async {
                    self.transcriptionResponses = responses
                    self.isLoading = false
                }
            } catch {
                print("Error loading transcription: \(error)")
                DispatchQueue.main.async {
                    self.transcriptionResponses = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct PlaceholderTranscriptionCard: View {
    let placeholder: PlaceholderTranscribedVideo
    
    var body: some View {
        VStack {
            AsyncImage(url: placeholder.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(placeholder.title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(placeholder.previewText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 150, height: 220)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}

struct ImportOptionsMenu: View {
    @Binding var isShowingImportOptions: Bool
    @Binding var photoPickerItem: PhotosPickerItem?
    @Binding var isShowingURLInput: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isShowingImportOptions {
                PhotosPicker(selection: $photoPickerItem, matching: .videos) {
                    ImportOptionButton(iconName: "square.and.arrow.down")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Button(action: { isShowingURLInput = true }) {
                    ImportOptionButton(iconName: "link")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Button(action: {
                withAnimation(.spring()) {
                    isShowingImportOptions.toggle()
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 5)
                    .rotationEffect(.degrees(isShowingImportOptions ? 45 : 0))
            }
        }
    }
}

struct ImportOptionButton: View {
    let iconName: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .shadow(radius: 3)
            
            Image(systemName: iconName)
                .foregroundColor(.white)
                .font(.system(size: 24))
        }
    }
}