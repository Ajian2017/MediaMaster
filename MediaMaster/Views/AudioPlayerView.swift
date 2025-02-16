import SwiftUI
import AVKit

struct AudioPlayerView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    let audioURL: URL
    
    var body: some View {
        Group {
            if viewModel.isReady {
                // 主视图内容
                VStack(spacing: 20) {
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
                }
                .padding()
            } else {
                // 加载指示器
                ProgressView("加载中...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .task {
            // 使用 task 修饰符来异步设置播放器
            await viewModel.setupPlayer(with: audioURL)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 