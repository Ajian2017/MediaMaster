//
//  MediaMasterApp.swift
//  MediaMaster
//
//  Created by Amob on 2025/2/13.
//

import SwiftUI

@main
struct MediaMasterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "mp3" {
                        // 创建 Input 文件夹
                        let fileManager = FileManager.default
                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let inputDirectoryURL = documentsURL.appendingPathComponent("Input")

                        // 检查并创建 Input 文件夹
                        if !fileManager.fileExists(atPath: inputDirectoryURL.path) {
                            do {
                                try fileManager.createDirectory(at: inputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                            } catch {
                                print("Error creating Input directory: \(error)")
                            }
                        }

                        // 生成唯一的文件名
                        let fileName = url.deletingPathExtension().lastPathComponent
                        let fileExtension = url.pathExtension
                        let timestamp = Int(Date().timeIntervalSince1970)
                        let uniqueFileName = "\(fileName)_\(timestamp).\(fileExtension)"
                        
                        // 移动接收到的文件到 Input 文件夹
                        let destinationURL = inputDirectoryURL.appendingPathComponent(uniqueFileName)
                        do {
                            if fileManager.fileExists(atPath: destinationURL.path) {
                                try fileManager.removeItem(at: destinationURL)
                            }
                            try fileManager.moveItem(at: url, to: destinationURL)
                            print("Successfully moved file to: \(destinationURL.path)")
                            NotificationCenter.default.post(name: NSNotification.Name("OpenAudioFile"), object: destinationURL)
                        } catch {
                            print("Error moving file to Input directory: \(error)")
                            // 如果移动失败，尝试复制
                            do {
                                try fileManager.copyItem(at: url, to: destinationURL)
                                print("Successfully copied file to: \(destinationURL.path)")
                                NotificationCenter.default.post(name: NSNotification.Name("OpenAudioFile"), object: destinationURL)
                            } catch {
                                print("Error copying file to Input directory: \(error)")
                            }
                        }
                    }
                }
        }
    }
}
