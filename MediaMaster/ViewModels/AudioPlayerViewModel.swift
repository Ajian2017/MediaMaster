import AVFoundation
import Combine

@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var audioURL: URL?
    @Published var isReady = false  // 添加准备状态标志
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    func setupPlayer(with url: URL) async {
        audioURL = url
        let asset = AVAsset(url: url)
        
        // 异步加载时长
        do {
            let duration = try await asset.load(.duration)
            self.duration = duration.seconds
            
            // 创建 AVPlayer
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // 添加时间观察器
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                self?.currentTime = time.seconds
            }
            
            // 标记准备完成
            isReady = true
        } catch {
            print("Error loading audio asset: \(error)")
        }
    }
    
    func play() {
        isPlaying = true
        player?.play()
    }
    
    func pause() {
        isPlaying = false
        player?.pause()
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player = nil
        timeObserver = nil
    }
} 