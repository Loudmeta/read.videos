import SwiftUI
import AVKit
import MarkdownUI

struct TranscriptionView: View {
    let videoURL: URL
    let transcriptionURL: URL
    @State private var transcriptionData: TranscriptionData?
    @State private var isVideoExpanded = false
    @State private var player: AVPlayer?
    @State private var selectedTab: Tab = .summary // Changed default tab to summary
    @Namespace private var animation
    @Environment(\.presentationMode) var presentationMode
    @State private var showToast = false
    @State private var toastMessage = ""
    
    enum Tab {
        case transcription, summary, topics
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                videoPlayerView
                videoInfoView
                tabSelectionView
                tabContentView
            }
            .navigationTitle("Video Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .overlay(
                ToastView(message: toastMessage, isShowing: $showToast)
                    .animation(.easeInOut, value: showToast)
            )
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            loadTranscriptionData()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private var videoPlayerView: some View {
        VideoPlayer(player: player)
            .frame(height: 200)
            .cornerRadius(15)
            .shadow(radius: 10)
            .padding(.horizontal)
            .padding(.top)
    }
    
    private var videoInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(videoURL.lastPathComponent)
                .font(.headline)
            Text(Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var tabSelectionView: some View {
        Picker("", selection: $selectedTab) {
            Text("Transcription").tag(Tab.transcription)
            Text("Summary").tag(Tab.summary)
            Text("Topics").tag(Tab.topics)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var tabContentView: some View {
        TabView(selection: $selectedTab) {
            transcriptionView
                .tag(Tab.transcription)
            
            summaryView
                .tag(Tab.summary)
            
            topicsView
                .tag(Tab.topics)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .padding(.top, 24)
    }
    
    private var transcriptionView: some View {
        ScrollView {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(transcriptionData?.segments ?? [], id: \.timestamp) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.timestamp)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(segment.text)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                
                copyButton(for: .transcription)
            }
        }
    }
    
    private var summaryView: some View {
        ScrollView {
            ZStack(alignment: .topTrailing) {
                if let transcriptionData = transcriptionData, !transcriptionData.summary.isEmpty {
                    Markdown(transcriptionData.summary)
                        .padding()
                } else {
                    Text("Summary not available")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                copyButton(for: .summary)
            }
        }
    }
    
    private var topicsView: some View {
        ScrollView {
            ZStack(alignment: .topTrailing) {
                if let transcriptionData = transcriptionData, !transcriptionData.topics.isEmpty {
                    Markdown(transcriptionData.topics)
                        .padding()
                } else {
                    Text("Topics not available")
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                copyButton(for: .topics)
            }
        }
    }
    
    private func copyButton(for tab: Tab) -> some View {
        Button(action: {
            copyToClipboard(for: tab)
        }) {
            Image(systemName: "doc.on.doc")
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .padding(8)
    }
    
    private func copyToClipboard(for tab: Tab) {
        var content = ""
        switch tab {
        case .transcription:
            content = transcriptionData?.segments.map { "\($0.timestamp): \($0.text)" }.joined(separator: "\n") ?? ""
        case .summary:
            content = transcriptionData?.summary ?? ""
        case .topics:
            content = transcriptionData?.topics ?? ""
        }
        
        UIPasteboard.general.string = content
        toastMessage = "Copied to clipboard"
        showToast = true
        
        // Hide the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
    
    private func loadTranscriptionData() {
        do {
            let data = try Data(contentsOf: transcriptionURL)
            let decoder = JSONDecoder()
            transcriptionData = try decoder.decode(TranscriptionData.self, from: data)
        } catch {
            print("Error loading transcription: \(error)")
            transcriptionData = TranscriptionData(
                segments: [TranscriptionData.Segment(timestamp: "Error", text: "Error loading transcription: \(error.localizedDescription)")],
                summary: "",
                topics: ""
            )
        }
    }
    
    private func saveTranscriptionData() {
        guard let transcriptionData = transcriptionData else { return }
        let fileURL = getTranscriptionDataFileURL()
        do {
            let data = try JSONEncoder().encode(transcriptionData)
            try data.write(to: fileURL)
        } catch {
            print("Error saving transcription data: \(error)")
        }
    }
    
    private func getTranscriptionDataFileURL() -> URL {
        let fileName = transcriptionURL.deletingPathExtension().lastPathComponent + "_data.json"
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if isShowing {
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
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
