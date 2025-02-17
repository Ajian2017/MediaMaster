import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import MobileCoreServices
import PDFKit

struct MovieTransferable: Transferable {
    let asset: AVAsset
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try data.write(to: fileURL)
            return MovieTransferable(asset: AVURLAsset(url: fileURL))
        }
    }
}

struct ContentView: View {
    @StateObject private var mergerViewModel = VideoMergerViewModel()
    @StateObject private var audioViewModel = AudioPlayerViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideos: [AVAsset] = []
    @State private var isVideoMode = false
    @State private var activeSheet: ActiveSheet? = nil
    @State private var audioURL: URL?
    @State private var currentAudio: URL? = nil
    @State private var isAudioMinimized = false
    @State private var selectedPDF: URL?
    
    enum ActiveSheet: Identifiable {
        case videoPreview(URL)
        case audioPlayer(URL)
        
        var id: Int {
            switch self {
            case .videoPreview: return 1
            case .audioPlayer: return 2
            }
        }
    }
    
    var body: some View {
        if isAudioMinimized, let url = currentAudio, let player = audioViewModel.player {
            MinimizedAudioPlayer(
                audioURL: url,
                isMinimized: $isAudioMinimized,
                viewModel: audioViewModel,
                onTap: { activeSheet = .audioPlayer(url) },
                onClose: {
                    audioViewModel.cleanup()
                    currentAudio = nil
                    isAudioMinimized = false
                }
            )
            .transition(.move(edge: .bottom))
            .ignoresSafeArea(.all, edges: .bottom)
        }
        TabView {
            homeView.tabItem {
                Label("Home", systemImage: "house")
            }
            InputFileListView(audioURL: $audioURL) { url in
                currentAudio = url
                activeSheet = .audioPlayer(url)
            }.tabItem {
                Label("File Center", systemImage: "folder")
            }
        }
    }
        
    var homeView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                    .navigationTitle(isVideoMode ? "视频合并" : "合并照片为PDF")
                    .padding(.bottom, isAudioMinimized ? 80 : 0)
                    .animation(.easeInOut, value: isAudioMinimized)
            }
            .sheet(item: $activeSheet) { sheetContent($0) }
        }
        .onChange(of: selectedItems, perform: handleSelectedItems)
        .onDrop(of: [.audio, .mp3, .mpeg4Audio, .wav, UTType.pdf], isTargeted: nil, perform: handleDrop)
        .onAppear { setupNotifications() }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private var mainContent: some View {
        MainContentView(
            isVideoMode: $isVideoMode,
            selectedItems: $selectedItems,
            selectedVideos: $selectedVideos,
            onMerge: mergeVideos
        )
    }
        
    @ViewBuilder
    func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .videoPreview(let url):
            VideoPlayerView(videoURL: url) {
                saveVideoToAlbum(url: url)
            }
        case .audioPlayer(let url):
            AudioPlayerView(
                viewModel: audioViewModel,
                isMinimized: $isAudioMinimized,
                audioURL: url,
                onMinimize: {
                    currentAudio = url
                }
            )
        }
    }
    
    func handleSelectedItems(_ newItems: [PhotosPickerItem]) {
        Task {
            selectedVideos = []
            for item in newItems {
                if let videoAsset = try? await item.loadTransferable(type: MovieTransferable.self) {
                    selectedVideos.append(videoAsset.asset)
                }
            }
        }
    }
    
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                provider.loadObject(ofClass: URL.self) { (url, error) in
                    if let url = url {
                        DispatchQueue.main.async {
                            self.selectedPDF = url
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func mergeVideos() {
        Task {
            await mergerViewModel.mergeVideos(selectedVideos)
            if let url = mergerViewModel.exportedVideoURL {
                activeSheet = .videoPreview(url)
            }
        }
    }
    
    private func saveVideoToAlbum(url: URL) {
        Task {
            let (success, error) = await PhotoLibraryManager.saveVideoToAlbum(url: url)
            await MainActor.run {
                if success {
                    mergerViewModel.alertMessage = "视频已保存到相册"
                } else {
                    mergerViewModel.alertMessage = "保存失败: \(error?.localizedDescription ?? "未知错误")"
                }
                mergerViewModel.showAlert = true
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenAudioFile"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.object as? URL {
                audioURL = url
                activeSheet = .audioPlayer(url)
            }
        }
    }
}

extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3", conformingTo: .audio)!
    static let wav = UTType(filenameExtension: "wav", conformingTo: .audio)!
    static let mpeg4Audio = UTType(filenameExtension: "m4a", conformingTo: .audio)!
}

// 修改最小化播放器视图
struct MinimizedAudioPlayer: View {
    let audioURL: URL
    @Binding var isMinimized: Bool
    @ObservedObject var viewModel: AudioPlayerViewModel
    let onTap: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 音乐图标
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            // 文件名和进度条
            VStack(alignment: .leading, spacing: 4) {
                Text(audioURL.lastPathComponent)
                    .lineLimit(1)
                    .font(.subheadline)
                
                ProgressView(value: viewModel.currentTime, total: viewModel.duration)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
            
            // 播放/暂停按钮
            Button(action: {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.play()
                }
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .frame(height: 60)
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 5)
        .onTapGesture(perform: onTap)
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct PDFViewer: View {
    let url: URL
    
    var body: some View {
        PDFKitView(url: url)
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
} 
