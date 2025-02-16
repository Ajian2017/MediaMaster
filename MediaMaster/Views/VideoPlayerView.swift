import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @StateObject private var viewModel = VideoPlayerViewModel()
    let videoURL: URL
    var onSave: () -> Void
    
    @State private var showingSaveAlert = false
    
    var body: some View {
        ZStack {
            VideoPlayer(player: viewModel.playerInstance)
                .ignoresSafeArea()
                .onAppear { viewModel.setupPlayer(with: videoURL) }
                .onDisappear { viewModel.cleanup() }
            
            VStack {
                Spacer()
                
                VideoControlsView(
                    currentTime: $viewModel.currentTime,
                    duration: viewModel.duration,
                    isPlaying: $viewModel.isPlaying,
                    onSeek: viewModel.seek(to:),
                    onPlayPause: viewModel.togglePlayback,
                    onSave: {
                        showingSaveAlert = true
                    }
                )
            }
        }
        .alert("保存视频", isPresented: $showingSaveAlert) {
            Button("取消", role: .cancel) { }
            Button("保存到相册") {
                onSave()
            }
            Button("保存到 Input") {
                saveToInput()
            }
        } message: {
            Text("选择保存位置")
        }
    }
    
    private func saveToInput() {
        do {
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let inputDirectoryURL = documentsURL.appendingPathComponent("Input")
            
            // 确保 Input 目录存在
            if !fileManager.fileExists(atPath: inputDirectoryURL.path) {
                try fileManager.createDirectory(at: inputDirectoryURL, withIntermediateDirectories: true)
            }
            
            // 生成唯一文件名
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "merged_video_\(timestamp).mp4"
            let destinationURL = inputDirectoryURL.appendingPathComponent(fileName)
            
            // 复制文件
            try fileManager.copyItem(at: videoURL, to: destinationURL)
            print("Successfully saved video to Input folder: \(destinationURL.path)")
            
            // 通知文件夹内容变化
            NotificationCenter.default.post(
                name: AudioFileManager.folderChangedNotification,
                object: nil
            )
        } catch {
            print("Error saving video to Input folder: \(error)")
        }
    }
}

struct VideoControlsView: View {
    @Binding var currentTime: Double
    let duration: Double
    @Binding var isPlaying: Bool
    let onSeek: (Double) -> Void
    let onPlayPause: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { onSeek($0) }
                ),
                in: 0...duration
            )
            .accentColor(.white)
            
            HStack {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(timeString(from: currentTime) + " / " + timeString(from: duration))
                    .foregroundColor(.white)
                    .font(.caption)
                
                Spacer()
                
                Button(action: onSave) {
                    Text("保存到相册")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 