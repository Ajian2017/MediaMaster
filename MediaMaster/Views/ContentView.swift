import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideos: [AVAsset] = []
    @State private var isVideoMode = false
    @State private var showingVideoPreview = false
    
    var body: some View {
        NavigationStack {
            VStack {
                ModePicker(isVideoMode: $isVideoMode)
                
                if isVideoMode {
                    VideoModeView(
                        selectedVideos: $selectedVideos,
                        onMerge: mergeVideos
                    )
                } else {
                    PhotoModeView(selectedItems: $selectedItems)
                }
                
                PhotosPicker(
                    selection: $selectedItems,
                    matching: isVideoMode ? .videos : .images
                ) {
                    Label(isVideoMode ? "选择视频" : "选择照片", 
                          systemImage: isVideoMode ? "video" : "photo")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
            .navigationTitle(isVideoMode ? "视频合并" : "相册浏览")
            .sheet(isPresented: $showingVideoPreview) {
                if let url = mergerViewModel.exportedVideoURL {
                    VideoPlayerView(videoURL: url) {
                        saveVideoToAlbum(url: url)
                    }
                }
            }
            .alert("提示", isPresented: $mergerViewModel.showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(mergerViewModel.alertMessage)
            }
            .overlay {
                if mergerViewModel.isExporting {
                    ProgressView("正在合并视频...")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    selectedVideos = []
                    for item in newItems {
                        if let videoAsset = try? await item.loadTransferable(type: MovieTransferable.self) {
                            selectedVideos.append(videoAsset.asset)
                        }
                    }
                }
            }
        }
    }
    
    private func mergeVideos() {
        Task {
            await mergerViewModel.mergeVideos(selectedVideos)
            if mergerViewModel.exportedVideoURL != nil {
                showingVideoPreview = true
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
} 