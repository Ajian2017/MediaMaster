import Foundation

class AudioFileManager {
    static let shared = AudioFileManager()
    
    private let fileManager = FileManager.default
    
    // 通知名称常量
    static let fileAddedNotification = NSNotification.Name("OpenAudioFile")
    static let folderChangedNotification = NSNotification.Name("FolderChanged")
    
    private init() {}
    
    // 获取 Input 目录 URL
    var inputDirectoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Input")
    }
    
    // 获取指定目录下的所有内容
    func getContents(at url: URL? = nil) -> [URL] {
        let targetURL = url ?? inputDirectoryURL
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: targetURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return contents.sorted { url1, url2 in
                // 文件夹排在前面
                let isDirectory1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let isDirectory2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDirectory1 != isDirectory2 {
                    return isDirectory1
                }
                return true
            }
        } catch {
            print("Error getting directory contents: \(error)")
            return []
        }
    }
    
    // 创建新文件夹
    func createFolder(named name: String, at url: URL? = nil) {
        let parentURL = url ?? inputDirectoryURL
        let folderURL = parentURL.appendingPathComponent(name)
        
        do {
            try fileManager.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
            print("Created folder at: \(folderURL.path)")
            notifyFolderChanged()
        } catch {
            print("Error creating folder: \(error)")
        }
    }
    
    // 删除文件或文件夹
    func delete(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
            print("Deleted item at: \(url.path)")
            notifyFolderChanged()
        } catch {
            print("Error deleting item: \(error)")
        }
    }
    
    // 移动文件到指定文件夹
    func moveFile(_ fileURL: URL, to folderURL: URL) throws {
        // 使用原始文件名（不添加时间戳）
        let destinationURL = folderURL.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            // 如果目标文件已存在，先删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 读取源文件数据
            let fileData = try Data(contentsOf: fileURL)
            
            // 写入新文件
            try fileData.write(to: destinationURL)
            
            // 删除源文件
            try fileManager.removeItem(at: fileURL)
            
            print("Successfully moved file from: \(fileURL.path)")
            print("To: \(destinationURL.path)")
            notifyFolderChanged()
        } catch {
            print("Error moving file: \(error)")
            throw error
        }
    }
    
    // 处理外部打开的音频文件
    func handleExternalAudioFile(_ url: URL) {
        let suffixs = ["mp3", "pdf"]
        guard suffixs.contains(url.pathExtension.lowercased()) else { return }
        
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
                name: Self.fileAddedNotification,
                object: url
            )
        }
    }
    
    // 通知文件夹内容变化
    private func notifyFolderChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.folderChangedNotification,
                object: nil
            )
        }
    }
    
    // 检查是否是文件夹
    func isDirectory(url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
    
    // 重命名文件或文件夹
    func rename(_ url: URL, to newName: String) throws {
        let parentURL = url.deletingLastPathComponent()
        let newURL = parentURL.appendingPathComponent(newName)
        
        // 检查新名称是否已存在
        if fileManager.fileExists(atPath: newURL.path) {
            throw NSError(
                domain: "AudioFileManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "该名称已存在"]
            )
        }
        
        do {
            try fileManager.moveItem(at: url, to: newURL)
            print("Successfully renamed from: \(url.lastPathComponent) to: \(newName)")
            notifyFolderChanged()
        } catch {
            print("Error renaming item: \(error)")
            throw error
        }
    }    
}
