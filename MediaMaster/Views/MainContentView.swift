import SwiftUI
import PhotosUI
import AVFoundation

struct MainContentView: View {
    @Binding var isVideoMode: Bool
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var selectedVideos: [AVAsset]
    let onMerge: () -> Void
    
    var body: some View {
        VStack {
            ModePicker(isVideoMode: $isVideoMode)
            
            if isVideoMode {
                VideoModeView(
                    selectedVideos: $selectedVideos,
                    onMerge: onMerge
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
    }
} 