import SwiftUI
import AVFoundation

struct VideoModeView: View {
    @Binding var selectedVideos: [AVAsset]
    @ObservedObject var viewModel: VideoMergerViewModel
    
    var body: some View {
        VStack {
            if selectedVideos.isEmpty {
                ContentUnavailableView(
                    "暂无视频",
                    systemImage: "video",
                    description: Text("点击下方按钮选择视频")
                )
            } else {
                // 显示已选视频数量
                Text("已选择 \(selectedVideos.count) 个视频")
                    .padding()
                
                // Show success message if available
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .padding()
                } else {
                    // 合并视频按钮
                    Button(action: {
                        Task {
                            await viewModel.mergeVideos(selectedVideos)
                        }
                    }) {
                        Label("合并视频", systemImage: "film.stack")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .disabled(selectedVideos.count < 2)
                }
                
                // Show progress indicator
                if viewModel.isExporting {
                    ProgressView("合并中...", value: viewModel.progress, total: 100)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                }
            }
            Spacer()
        }
        .onChange(of: selectedVideos) { _ in
            viewModel.reset() // Reset success message when videos change
        }
    }
} 