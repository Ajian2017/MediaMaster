import SwiftUI
import PhotosUI
import AVFoundation

struct MainContentView: View {
    @Binding var isVideoMode: Bool
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var selectedVideos: [AVAsset]
    @StateObject private var videoMergerViewModel = VideoMergerViewModel()
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case videoPreview(URL)
        
        var id: Int {
            switch self {
            case .videoPreview: return 1
            }
        }
    }
    
    var body: some View {
        VStack {
            ModePicker(isVideoMode: $isVideoMode)
            
            if isVideoMode {
                VideoModeView(
                    selectedVideos: $selectedVideos,
                    viewModel: videoMergerViewModel
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
        .onChange(of: videoMergerViewModel.exportedVideoURL) { url in
            if let url = url {
                activeSheet = .videoPreview(url) // Open the merged video
            }
        }
        .sheet(item: $activeSheet) { sheetContent($0) }
    }
    
    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .videoPreview(let url):
            VideoPlayerView(videoURL: url) {
                // Handle any actions after video playback
            }
        }
    }
} 
