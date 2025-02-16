import Foundation

class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // 获取 Input 目录 URL
    var inputDirectoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Input")
    }
    
    // 处理外部打开的音频文件
    func handleExternalAudioFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "mp3" else { return }
        
        // 确保 Input 目录存在
        createInputDirectoryIfNeeded()
        
        // 生成唯一文件名
        let destinationURL = generateUniqueFileURL(for: url)
        
        // 移动或复制文件
        moveOrCopyFile(from: url, to: destinationURL)
    }
    
    // 创建 Input 目录
    private func createInputDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: inputDirectoryURL.path) {
            do {
                try fileManager.createDirectory(
                    at: inputDirectoryURL,
                    withIntermediateDirectories: true
                )
                print("Created Input directory at: \(inputDirectoryURL.path)")
            } catch {
                print("Error creating Input directory: \(error)")
            }
        }
    }
    
    // 生成唯一文件名
    private func generateUniqueFileURL(for url: URL) -> URL {
        let fileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        let timestamp = Int(Date().timeIntervalSince1970)
        let uniqueFileName = "\(fileName)_\(timestamp).\(fileExtension)"
        return inputDirectoryURL.appendingPathComponent(uniqueFileName)
    }
    
    // 移动或复制文件
    private func moveOrCopyFile(from sourceURL: URL, to destinationURL: URL) {
        do {
            // 如果目标文件已存在，先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 尝试移动文件
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            print("Successfully moved file to: \(destinationURL.path)")
            notifyFileAdded(destinationURL)
        } catch {
            print("Error moving file, attempting to copy: \(error)")
            
            // 如果移动失败，尝试复制
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                print("Successfully copied file to: \(destinationURL.path)")
                notifyFileAdded(destinationURL)
            } catch {
                print("Error copying file: \(error)")
            }
        }
    }
    
    // 通知文件添加完成
    private func notifyFileAdded(_ url: URL) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAudioFile"),
                object: url
            )
        }
    }
} 