import SwiftUI
import AVKit

struct AudioPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Binding var isMinimized: Bool
    let audioURL: URL
    let onMinimize: () -> Void
    
    init(
        viewModel: AudioPlayerViewModel,
        isMinimized: Binding<Bool>,
        audioURL: URL,
        onMinimize: @escaping () -> Void
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._isMinimized = isMinimized
        self.audioURL = audioURL
        self.onMinimize = onMinimize
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部关闭按钮
            HStack {
                Spacer()
                Button(action: {
                    viewModel.cleanup()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            // 音频波形或封面图片
            Image(systemName: "waveform")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .foregroundColor(.blue)
            
            // 文件名
            Text(audioURL.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // 进度条
            Slider(
                value: $viewModel.currentTime,
                in: 0...viewModel.duration
            ) { editing in
                if !editing {
                    viewModel.seek(to: viewModel.currentTime)
                }
            }
            
            HStack {
                Text(timeString(from: viewModel.currentTime))
                Spacer()
                Text(timeString(from: viewModel.duration))
            }
            .font(.caption)
            
            // 播放控制按钮
            HStack(spacing: 40) {
                Button(action: {
                    viewModel.seek(to: max(0, viewModel.currentTime - 15))
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                }
                
                Button(action: {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                
                Button(action: {
                    viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 15))
                }) {
                    Image(systemName: "goforward.15")
                        .font(.title)
                }
            }
            
            // 最小化按钮
            Button(action: {
                onMinimize()
                isMinimized = true
                dismiss()
            }) {
                Text("点击最小化")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top)
        }
        .padding()
        .task {
            if !viewModel.isReady || viewModel.audioURL != audioURL {
                await viewModel.setupPlayer(with: audioURL)
            }
        }
        .onDisappear {
            if !isMinimized {
                viewModel.cleanup()
            }
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 