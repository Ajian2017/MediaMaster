import SwiftUI

// 最小化播放器视图
struct MinimizedAudioPlayer: View {
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
                Text(viewModel.audioURL?.lastPathComponent ?? "Unknown Track")
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
        .onReceive(viewModel.$audioURL) { _ in
            // Update the UI when audioURL changes
        }
        .onReceive(viewModel.$currentTime) { _ in
            // Update the UI when currentTime changes
        }
    }
}
