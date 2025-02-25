import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import MobileCoreServices

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
        if isAudioMinimized, let url = audioViewModel.audioURL, let _ = audioViewModel.player {
            MinimizedAudioPlayer(
                isMinimized: $isAudioMinimized,
                viewModel: audioViewModel,
                onTap: { activeSheet = .audioPlayer(url) },
                onClose: {
                    audioViewModel.cleanup()
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
            InputFileListView() { url in
                activeSheet = .audioPlayer(url)
            }.tabItem {
                Label("File Center", systemImage: "folder")
            }
            SettingsView()
                .environmentObject(audioViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            FileServerView().tabItem {
                Label("wife传输", systemImage: "wifi.circle")
            }
        }
    }
        
    var homeView: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                    .navigationTitle(isVideoMode ? "视频合并" : "合并照片为PDF")
//                    .padding(.top, isAudioMinimized ? 80 : 0)
                    .animation(.easeInOut, value: isAudioMinimized)
            }
            .sheet(item: $activeSheet) { sheetContent($0) }
        }
        .onChange(of: selectedItems) { oldValue, selectedItems in
            handleSelectedItems(selectedItems)
        }
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
            selectedVideos: $selectedVideos
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
                onMinimize: {}
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
