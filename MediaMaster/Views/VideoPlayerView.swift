import SwiftUI
import AVKit

// 视频播放器容器视图
struct VideoPlayerContainerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.frame = uiView.bounds
            layer.player = player
        }
    }
}

struct VideoPlayerView: View {
    @StateObject private var viewModel = VideoPlayerViewModel()
    let videoURL: URL
    var onSave: () -> Void
    
    @State private var showingSaveAlert = false
    @State private var selectedFileToShare: URL?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VideoPlayerContainerView(player: viewModel.playerInstance)
            .ignoresSafeArea()
            .onAppear { 
                viewModel.setupPlayer(with: videoURL) 
            }
            .onDisappear { viewModel.cleanup() }
            .onChange(of: scenePhase) { _, phase in
                print("Scene phase changed to: \(phase)")
                switch phase {
                case .background:
                    // 进入后台时继续播放
                    viewModel.setupBackgroundPlayback()
                case .inactive:
                    // 应用即将进入后台，确保设置好后台播放
                    viewModel.setupBackgroundPlayback()
                case .active:
                    // 返回前台时恢复播放
                    if viewModel.isPlaying {
                        viewModel.playerInstance?.play()
                    }
                @unknown default:
                    break
                }
            }
            .overlay(
                VStack {
                    Spacer()
                    VideoControlsView(
                        currentTime: $viewModel.currentTime,
                        duration: viewModel.duration,
                        isPlaying: $viewModel.isPlaying,
                        onSeek: viewModel.seek(to:),
                        onPlayPause: viewModel.togglePlayback,
                        onSave: { showingSaveAlert = true }
                    )
                    Button(action: shareFile) {
                        Text("分享")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            )
            .alert("保存视频", isPresented: $showingSaveAlert) {
                Button("取消", role: .cancel) { }
                Button("保存到相册") { onSave() }
                Button("保存到 Input") { saveToInput() }
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
            
            // 通知文件夹内容变化
            NotificationCenter.default.post(
                name: AudioFileManager.folderChangedNotification,
                object: nil
            )
        } catch {
            print("Error saving video to Input folder: \(error)")
        }
    }
    
    private func shareFile() {
        guard let fileToShare = selectedFileToShare else {
            print("No file selected to share") // Debugging line
            return
        }
        
        // Check if the file exists
        if !FileManager.default.fileExists(atPath: fileToShare.path) {
            print("File does not exist at path: \(fileToShare.path)") // Debugging line
            return
        }
        
        print("Sharing file: \(fileToShare)") // Debugging line
        let activityViewController = UIActivityViewController(activityItems: [fileToShare], applicationActivities: nil)
        
        // Present the activity view controller on the main thread
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityViewController, animated: true, completion: nil)
            } else {
                print("Could not find root view controller") // Debugging line
            }
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