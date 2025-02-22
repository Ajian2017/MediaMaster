import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var audioURL: URL?
    @Published var isReady = false
    @Published var playlist: [URL] = []  // 添加播放列表
    @Published var remainingTime: Int = 0 // Add remaining time property
    
    var player: AVPlayer?
    private var timeObserver: Any?
    private var currentIndex: Int = 0
    private var isShuttingDown = false  // 添加标志以防止重复清理
    private var timer: AnyCancellable? // 添加定时器
    private var countdownTimer: AnyCancellable? // Timer for countdown

    func setupPlayer(with url: URL) async {
        // 如果已经在播放同一个文件，不需要重新设置
        if audioURL == url && isReady {
            return
        }
        
        isReady = false
        isShuttingDown = false
        
        // 加载播放列表
        loadPlaylist(url)
        
        // 设置当前播放索引
        if let index = playlist.firstIndex(of: url) {
            currentIndex = index
        }
        
        // 等待设置当前曲目完成
        do {
            try await setupCurrentTrack()
            isPlaying = true
            play()
        } catch {
            print("Error setting up player: \(error)")
        }
    }
    
    private func loadPlaylist(_ url: URL? = nil) {
        let inputDirectoryURL = url?.deletingLastPathComponent() ?? AudioFileManager.shared.inputDirectoryURL
        
        let files = AudioFileManager.shared.getContents(at: inputDirectoryURL)
        playlist = files
            .filter { $0.pathExtension.lowercased() == "mp3" }
        print("Loaded playlist: \(playlist.count) files")
    }
    
    private func setupCurrentTrack() async throws {
        guard !isShuttingDown && currentIndex < playlist.count else { 
            throw NSError(domain: "AudioPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid track index"])
        }
        
        // 清理之前的播放器
        cleanup(keepSession: true)
        
        let url = playlist[currentIndex]
        audioURL = url
        let asset = AVAsset(url: url)
        
        // 设置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
            throw error
        }
        
        // 异步加载时长
        do {
            let duration = try await asset.load(.duration)
            self.duration = duration.seconds
            
            // 创建 AVPlayer
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // 设置远程控制和锁屏信息
            setupRemoteTransportControls()
            setupNowPlaying(url: url)
            
            // 添加新的时间观察器
            timeObserver = player?.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self = self else { return }
                Task { @MainActor in
                    self.currentTime = time.seconds
                    self.updateNowPlayingInfo()
                }
            }
            
            // 添加播放完成通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePlayToEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            print("Successfully set up track: \(url.lastPathComponent)")
            isReady = true
            
        } catch {
            print("Error loading audio asset: \(error)")
            throw error
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    private func setupNowPlaying(url: URL) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = url.lastPathComponent
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    @objc private func handlePlayToEnd() {
        Task { @MainActor in
            guard !isShuttingDown else { return }
            
            do {
                currentIndex = (currentIndex + 1) % playlist.count
                try await setupCurrentTrack()
                if !isShuttingDown {
                    play()
                    print("Started playing next track: \(playlist[currentIndex].lastPathComponent)")
                }
            } catch {
                print("Error setting up next track: \(error)")
            }
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
        updateNowPlayingInfo()
    }
    
    func cleanup(keepSession: Bool = false) {
        guard !isShuttingDown else { return }
        isShuttingDown = true
        
        pause()
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        player = nil
        
        // 清理锁屏信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // 停用音频会话（如果需要）
        if !keepSession {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        
        isShuttingDown = false
        isReady = false
    }

    func startTimer(for duration: Int) {
        stopTimer() // Stop any existing timer
        remainingTime = duration * 60 // Set remaining time
        
        // Start a countdown every second
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.remainingTime > 0 else { return }
                self.remainingTime -= 1
                if (self.remainingTime <= 0) {
                    self.pause() // Pause music when timer expires
                    self.remainingTime = 0 // Reset remaining time
                }
            }
    }

    func stopTimer() {
        countdownTimer?.cancel() // Stop countdown timer
        countdownTimer = nil
        remainingTime = 0 // Reset remaining time
    }
} 

