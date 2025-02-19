import AVFoundation
import ffmpegkit

@MainActor
class VideoMergerViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var exportedVideoURL: URL?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var progress: Double = 0.0
    @Published var successMessage: String?
    
    private var inputDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Input")
    }
    
    func reset() {
        successMessage = nil // Reset success message
    }
    
    func mergeVideos(_ videos: [AVAsset]) async {
        guard videos.count >= 2 else { return }
        
        isExporting = true
        progress = 0.0
        successMessage = nil
        
        do {
            let tempDirURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("videoMerge_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
            
            var standardizedVideos: [String] = []
            
            // 1. 先转换所有视频到相同格式
            for (index, asset) in videos.enumerated() {
                if let urlAsset = asset as? AVURLAsset {
                    let tempVideoURL = tempDirURL.appendingPathComponent("video\(index).mp4")
                    try FileManager.default.copyItem(at: urlAsset.url, to: tempVideoURL)
                    
                    // 转换视频
                    let standardizedURL = tempDirURL.appendingPathComponent("std_video\(index).mp4")
                    let standardizeCommand = "-i \(tempVideoURL.path) -vf scale=1280:720 -c:v h264_videotoolbox -b:v 5M -c:a aac -b:a 192k -y \(standardizedURL.path)"
                    
                    let result = await withCheckedContinuation { continuation in
                        FFmpegKit.executeAsync(standardizeCommand) { session in
                            if let session = session,
                               let returnCode = session.getReturnCode(),
                               returnCode.isValueSuccess() {
                                standardizedVideos.append(standardizedURL.path)
                                print("Successfully standardized video \(index)")
                            } else {
                                print("Standardize Error for video \(index): \(session?.getLogsAsString() ?? "Unknown error")")
                            }
                            continuation.resume(returning: session?.getReturnCode()?.isValueSuccess() ?? false)
                        }
                    }
                    
                    if !result {
                        throw NSError(domain: "FFmpegError", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频标准化失败"])
                    }
                }
            }
            
            // 2. 创建文件列表
            let fileList = standardizedVideos
                .map { "file '\($0)'" }
                .joined(separator: "\n")
            
            let listPath = tempDirURL.appendingPathComponent("files.txt").path
            try fileList.write(toFile: listPath, atomically: true, encoding: .utf8)
            
            // 3. 合并视频
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("merged_video_\(Date().timeIntervalSince1970)")
                .appendingPathExtension("mp4")
            
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            
            // 使用 concat demuxer 合并
            let mergeCommand = "-f concat -safe 0 -i \(listPath) -c copy -y \(outputURL.path)"
            
            return await withCheckedContinuation { continuation in
                FFmpegKit.executeAsync(mergeCommand) { [weak self] session in
                    Task { @MainActor in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        if let session = session {
                            let logs = session.getLogsAsString() ?? ""
                            self.updateProgress(from: logs)
                            
                            if let returnCode = session.getReturnCode(),
                               returnCode.isValueSuccess() {
                                self.exportedVideoURL = outputURL
                                self.successMessage = "视频合并成功！"
                                print("Successfully merged videos")
                            } else {
                                print("FFmpeg Merge Error: \(session.getLogsAsString() ?? "Unknown error")")
                                self.alertMessage = "视频合并失败：\(session.getLogsAsString() ?? "未知错误")"
                                self.showAlert = true
                            }
                        }
                        
                        try? FileManager.default.removeItem(at: tempDirURL)
                        self.isExporting = false
                        continuation.resume()
                    }
                }
            }
            
        } catch {
            print("Merge Error: \(error.localizedDescription)")
            alertMessage = "准备合并失败：\(error.localizedDescription)"
            showAlert = true
            isExporting = false
        }
    }
    
    private func updateProgress(from logs: String) {
        let progressPattern = "time=(\\d+\\.\\d+)"
        let regex = try? NSRegularExpression(pattern: progressPattern, options: [])
        let nsString = logs as NSString
        let results = regex?.matches(in: logs, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results?.last, let range = Range(match.range(at: 1), in: logs) {
            let timeString = String(logs[range])
            if let time = Double(timeString) {
                let totalDuration = 10.0 // Replace with actual duration if available
                self.progress = min(time / totalDuration * 100.0, 100.0)
            }
        }
    }
    
    func extractAudio(from videos: [AVAsset]) async {
        guard !videos.isEmpty else { return }
        
        isExporting = true
        progress = 0.0
        successMessage = nil
        
        do {
            // Ensure the input directory exists
            try FileManager.default.createDirectory(at: inputDirectoryURL, withIntermediateDirectories: true)
            
            for (index, asset) in videos.enumerated() {
                if let urlAsset = asset as? AVURLAsset {
                    // Change the output file extension to .mp3
                    let audioOutputURL = inputDirectoryURL.appendingPathComponent("audio\(index).mp3")
                    
                    // FFmpeg command to extract audio in MP3 format
                    let extractCommand = "-i \(urlAsset.url.path) -q:a 0 -map a -codec:a libmp3lame \(audioOutputURL.path)"
                    
                    let result = await withCheckedContinuation { continuation in
                        FFmpegKit.executeAsync(extractCommand) { session in
                            if let session = session,
                               let returnCode = session.getReturnCode(),
                               returnCode.isValueSuccess() {
                                print("Successfully extracted audio from video \(index)")
                            } else {
                                print("Audio Extraction Error for video \(index): \(session?.getLogsAsString() ?? "Unknown error")")
                            }
                            continuation.resume(returning: session?.getReturnCode()?.isValueSuccess() ?? false)
                        }
                    }
                    
                    if !result {
                        throw NSError(domain: "FFmpegError", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频提取失败"])
                    }
                }
            }
            
            successMessage = "音频提取成功！"
            print("Audio extraction completed successfully.")
        } catch {
            print("Audio Extraction Error: \(error.localizedDescription)")
            alertMessage = "音频提取失败：\(error.localizedDescription)"
            showAlert = true
        }
        
        isExporting = false
    }
} 