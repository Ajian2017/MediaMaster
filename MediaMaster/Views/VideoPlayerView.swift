import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @StateObject private var viewModel = VideoPlayerViewModel()
    let videoURL: URL
    var onSave: () -> Void
    
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
                    onSave: onSave
                )
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