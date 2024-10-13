import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var selectedVideo: URL?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var transcribedVideos: [TranscribedVideo] = []
    @State private var isImporting = false
    @State private var importError: IdentifiableError?
    @State private var selectedTranscription: TranscribedVideo?
    @State private var isShowingImportOptions = false
    @State private var isSelectMode = false
    @State private var selectedItems: Set<UUID> = []
    @Namespace private var animation
    @State private var isProcessing = false
    @State private var isShowingDocumentPicker = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(transcribedVideos) { video in
                            TranscriptionCard(video: video, namespace: animation, isSelected: selectedItems.contains(video.id))
                                .onTapGesture {
                                    if isSelectMode {
                                        toggleSelection(for: video)
                                    } else {
                                        selectedTranscription = video
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
                .navigationBarTitleDisplayMode(.large)
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
                            importFromFiles: importFromFiles,
                            takeVideo: takeVideo
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .sheet(item: $selectedTranscription) { video in
                TranscriptionView(videoURL: video.videoURL, transcriptionURL: video.transcriptionURL)
            }
            .overlay {
                if isImporting || isProcessing {
                    ProgressView("Processing video...")
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
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            loadTranscribedVideos()
        }
        .onChange(of: photoPickerItem) { oldValue, newValue in
            if let newValue = newValue {
                withAnimation(.spring()) {
                    isShowingImportOptions = false
                }
                Task {
                    await importVideo(from: newValue)
                }
                photoPickerItem = nil
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            documentPicker
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
        isProcessing = true
        defer { 
            isImporting = false
            isProcessing = false
        }
        
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
            
            let processedVideo = try await APIService.shared.processVideo(url: fileURL)
            transcribedVideos.insert(processedVideo, at: 0)
            saveTranscribedVideos()
        } catch {
            importError = IdentifiableError(error: "Error processing video: \(error.localizedDescription)")
        }
    }
    
    private func importFromFiles() {
        isShowingDocumentPicker = true
    }
    
    private func takeVideo() {
        // Implement video recording functionality here
        // You may want to use UIImagePickerController or AVFoundation for this
        print("Take video functionality to be implemented")
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

// Move UIDocumentPickerDelegate conformance to a separate UIViewControllerRepresentable
struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.movie], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

// Extend HomeView to include the DocumentPicker
extension HomeView {
    var documentPicker: some View {
        DocumentPicker { url in
            Task {
                await processImportedVideo(at: url)
            }
        }
    }
    
    private func processImportedVideo(at url: URL) async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let processedVideo = try await APIService.shared.processVideo(url: url)
            transcribedVideos.insert(processedVideo, at: 0)
            saveTranscribedVideos()
        } catch {
            importError = IdentifiableError(error: "Error processing video: \(error.localizedDescription)")
        }
    }
}

struct ImportOptionsMenu: View {
    @Binding var isShowingImportOptions: Bool
    @Binding var photoPickerItem: PhotosPickerItem?
    let importFromFiles: () -> Void
    let takeVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if isShowingImportOptions {
                PhotosPicker(selection: $photoPickerItem, matching: .videos) {
                    ImportOptionButton(iconName: "photo")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Button(action: importFromFiles) {
                    ImportOptionButton(iconName: "folder")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Button(action: takeVideo) {
                    ImportOptionButton(iconName: "camera")
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
                .font(.appCaption())
                .lineLimit(1)
                .truncationMode(.middle)
            
            Text(transcriptionPreview)
                .font(.appCaption())
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
                let transcriptionData = try decoder.decode(TranscriptionData.self, from: data)
                let previewText = transcriptionData.summary.split(separator: "\n").first ?? "No summary available"
                let words = previewText.split(separator: " ")
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
                                .font(.appHeadline())
                            Text(video.createdAt, style: .date)
                                .font(.appSubheadline())
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