//
//  ContentView.swift
//  MediaMaster
//
//  Created by Amob on 2025/2/13.
//

import SwiftUI
import PhotosUI
import PDFKit
import AVFoundation
import ffmpegkit  // 添加 FFmpeg 导入
import AVKit  // 添加用于视频预览

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideos: [AVAsset] = []
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var isVideoMode = false
    @State private var isExporting = false
    @State private var exportedVideoURL: URL?
    @State private var showingVideoPreview = false  // 添加视频预览状态
    @State private var showingAlert = false  // 添加提示状态
    @State private var alertMessage = ""  // 添加提示信息
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var timeObserver: Any?  // 添加时间观察器引用
    
    var body: some View {
        NavigationStack {
            VStack {
                // 模式切换
                Picker("模式选择", selection: $isVideoMode) {
                    Text("照片").tag(false)
                    Text("视频").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isVideoMode {
                    // 视频模式
                    if selectedVideos.isEmpty {
                        ContentUnavailableView(
                            "暂无视频",
                            systemImage: "video",
                            description: Text("点击下方按钮选择视频")
                        )
                    } else {
                        // 显示已选视频数量
                        Text("已选择 \(selectedVideos.count) 个视频")
                            .padding()
                        
                        // 合并视频按钮
                        Button(action: mergeVideos) {
                            Label("合并视频", systemImage: "film.stack")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .disabled(selectedVideos.count < 2)
                    }
                } else {
                    // 照片模式
                    if selectedImages.isEmpty {
                        ContentUnavailableView(
                            "暂无照片",
                            systemImage: "photo.on.rectangle",
                            description: Text("点击下方按钮选择照片")
                        )
                    } else {
                        // 显示选择的图片
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100, maximum: 200))
                            ], spacing: 10) {
                                ForEach(0..<selectedImages.count, id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 100, maxWidth: 200, minHeight: 100, maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding()
                        }
                        
                        // 生成PDF按钮
                        Button(action: createAndSharePDF) {
                            Label("生成PDF", systemImage: "doc.badge.plus")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        .disabled(selectedImages.isEmpty)
                    }
                }
                
                // 选择器按钮
                PhotosPicker(
                    selection: $selectedItems,
                    matching: isVideoMode ? .videos : .images,
                    photoLibrary: .shared()
                ) {
                    Label(isVideoMode ? "选择视频" : "选择照片", 
                          systemImage: isVideoMode ? "video.badge.plus" : "photo.stack")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
            }
            .onChange(of: selectedItems) { newItems in
                Task {
                    if isVideoMode {
                        selectedVideos = []
                        for item in newItems {
                            if let videoAsset = try? await item.loadTransferable(type: MovieTransferable.self) {
                                selectedVideos.append(videoAsset.asset)
                            }
                        }
                    } else {
                        selectedImages = []
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImages.append(image)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isVideoMode ? "视频合并" : "相册浏览")
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(items: [pdfData])
                } else if let videoURL = exportedVideoURL {
                    ShareSheet(items: [videoURL])
                }
            }
            .sheet(isPresented: $showingVideoPreview) {
                if let videoURL = exportedVideoURL {
                    ZStack {
                        VideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                setupPlayer(with: videoURL)
                            }
                            .onDisappear {
                                cleanupPlayer()
                            }
                        
                        VStack {
                            Spacer()
                            
                            // 添加自定义控制栏
                            VStack(spacing: 10) {
                                // 进度条
                                Slider(
                                    value: Binding(
                                        get: { currentTime },
                                        set: { newValue in
                                            currentTime = newValue
                                            let time = CMTime(seconds: newValue, preferredTimescale: 600)
                                            player?.seek(to: time)
                                        }
                                    ),
                                    in: 0...duration
                                )
                                .accentColor(.white)
                                
                                HStack {
                                    // 播放/暂停按钮
                                    Button(action: togglePlayback) {
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    
                                    // 时间显示
                                    Text(timeString(from: currentTime) + " / " + timeString(from: duration))
                                        .foregroundColor(.white)
                                        .font(.caption)
                                    
                                    Spacer()
                                    
                                    // 保存按钮
                                    Button(action: saveVideoToAlbum) {
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
                            .background(
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .ignoresSafeArea()
                            )
                        }
                    }
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if isExporting {
                    ProgressView("正在合并视频...")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func createAndSharePDF() {
        let pdfDocument = PDFDocument()
        
        // 设置PDF页面大小为A4
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4尺寸，72 DPI
        
        for (index, image) in selectedImages.enumerated() {
            // 创建一个新的PDF页面上下文
            let pdfPage = PDFPage()
            UIGraphicsBeginPDFPage()
            
            // 计算图片在页面中的位置和大小
            let imageSize = image.size
            let aspectRatio = imageSize.width / imageSize.height
            var drawRect = CGRect.zero
            
            if aspectRatio > 1 {
                // 横向图片
                let width = pageRect.width - 40 // 左右各留20点边距
                let height = width / aspectRatio
                drawRect = CGRect(
                    x: 20,
                    y: (pageRect.height - height) / 2,
                    width: width,
                    height: height
                )
            } else {
                // 纵向图片
                let height = pageRect.height - 40 // 上下各留20点边距
                let width = height * aspectRatio
                drawRect = CGRect(
                    x: (pageRect.width - width) / 2,
                    y: 20,
                    width: width,
                    height: height
                )
            }
            
            // 绘制图片
            image.draw(in: drawRect)
            
            // 创建PDF页面并添加到文档
            if let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: index)
            }
        }
        
        // 获取PDF数据
        if let data = pdfDocument.dataRepresentation() {
            pdfData = data
            showingShareSheet = true
        }
    }
    
    private func mergeVideos() {
        guard selectedVideos.count >= 2 else { return }
        
        isExporting = true
        
        Task {
            do {
                // 创建临时目录来存放视频文件
                let tempDirURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("videoMerge_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
                
                // 创建临时文件列表
                let tempListURL = tempDirURL.appendingPathComponent("videos.txt")
                
                // 创建输出文件路径
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("merged_video_\(Date().timeIntervalSince1970)")
                    .appendingPathExtension("mp4")
                
                // 删除可能存在的旧文件
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                
                // 创建文件列表内容
                var fileListContent = ""
                var index = 0
                
                // 复制视频文件到临时目录并创建文件列表
                for asset in selectedVideos {
                    if let urlAsset = asset as? AVURLAsset {
                        let tempVideoURL = tempDirURL.appendingPathComponent("video\(index).mp4")
                        if let videoData = try? Data(contentsOf: urlAsset.url) {
                            try videoData.write(to: tempVideoURL)
                            fileListContent += "file '\(tempVideoURL.path)'\n"
                            index += 1
                        }
                    }
                }
                
                // 写入文件列表
                try fileListContent.write(to: tempListURL, atomically: true, encoding: .utf8)
                
                // 构建 FFmpeg 命令，添加更多参数以确保正确合并
                let command = "-f concat -safe 0 -i \(tempListURL.path) -c:v copy -c:a aac -strict experimental \(outputURL.path)"
                
                // 执行 FFmpeg 命令
                await FFmpegKit.executeAsync(command) { session in
                    Task { @MainActor in
                        guard let session = session else {
                            print("Error: FFmpeg session is nil")
                            isExporting = false
                            return
                        }
                        
                        if let returnCode = session.getReturnCode(),
                           returnCode.isValueSuccess() {
                            // 合并成功
                            exportedVideoURL = outputURL
                            showingVideoPreview = true
                        } else {
                            // 合并失败
                            print("Error merging videos: \(session.getLogsAsString() ?? "Unknown error")")
                            alertMessage = "视频合并失败：\(session.getLogsAsString() ?? "未知错误")"
                            showingAlert = true
                        }
                        
                        // 清理临时文件
                        try? FileManager.default.removeItem(at: tempDirURL)
                        isExporting = false
                    }
                }
                
            } catch {
                print("Error preparing video merge: \(error.localizedDescription)")
                await MainActor.run {
                    alertMessage = "准备合并失败：\(error.localizedDescription)"
                    showingAlert = true
                    isExporting = false
                }
            }
        }
    }
    
    private func saveVideoToAlbum() {
        guard let videoURL = exportedVideoURL else { return }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                alertMessage = "需要相册访问权限来保存视频"
                showingAlert = true
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        alertMessage = "视频已保存到相册"
                    } else {
                        alertMessage = "保存失败: \(error?.localizedDescription ?? "未知错误")"
                    }
                    showingAlert = true
                }
            }
        }
    }
    
    // 添加新的辅助函数
    private func setupPlayer(with url: URL) {
        // 创建播放器
        player = AVPlayer(url: url)
        
        // 获取视频时长
        if let playerItem = player?.currentItem {
            let duration = playerItem.asset.duration
            self.duration = CMTimeGetSeconds(duration)
        }
        
        // 添加时间观察器
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = CMTimeGetSeconds(time)
        }
        
        // 添加播放结束通知
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            player?.seek(to: .zero)
        }
        
        // 自动开始播放
        player?.play()
        isPlaying = true
    }
    
    private func cleanupPlayer() {
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 移除时间观察器
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        timeObserver = nil
        
        // 停止并清理播放器
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 1
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// 修改 MovieTransferable 以保存视频 URL
struct MovieTransferable: Transferable {
    let asset: AVURLAsset
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try data.write(to: fileURL)
            return MovieTransferable(asset: AVURLAsset(url: fileURL))
        }
    }
}

// 用于显示系统分享sheet的包装视图
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 创建一个临时URL来保存PDF文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("document.pdf")
        
        // 将items中的PDF数据写入临时文件
        if let pdfData = items.first as? Data {
            try? pdfData.write(to: tempURL)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

//#Preview {
//    ContentView()
//}
