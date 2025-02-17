import SwiftUI

struct InputFileListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var audioURL: URL?
    let onSelect: (URL) -> Void
    
    @State private var currentDirectory: URL?
    @State private var files: [URL] = []
    @State private var showingNewFolderAlert = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: URL?
    @State private var newFolderName = ""
    @State private var showingMoveSheet = false
    @State private var itemToMove: URL?
    @State private var selectedDestination: URL?
    @State private var showingVideoPlayer = false
    @State private var selectedVideo: URL?
    @State private var showingRenameAlert = false
    @State private var itemToRename: URL?
    @State private var newItemName = ""
    @State private var navigationPath = NavigationPath()
    @State private var selectedFileToShare: URL?
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let current = currentDirectory {
                    Button(action: {
                        currentDirectory = current.deletingLastPathComponent()
                        loadFiles()
                    }) {
                        HStack {
                            Image(systemName: "arrow.backward")
                            Text("返回上级")
                        }
                    }
                }
                
                ForEach(files, id: \.self) { file in
                    if file.pathExtension.lowercased() == "pdf" {
                        PDFFileView(url: file)
                            .onTapGesture {
                                navigationPath.append(file)
                            }
                            .contextMenu {
                                shareButton(for: file)
                                deleteButton(for: file)
                                renameButton(for: file)
                                moveButton(for: file)
                            }
                    } else {
                        let isDirectory = AudioFileManager.shared.isDirectory(url: file)
                        let isVideo = file.pathExtension.lowercased() == "mp4"
                        let isAudio = file.pathExtension.lowercased() == "mp3"
                        
                        if isVideo {
                            NavigationLink(value: file) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    onDelete: {
                                        itemToDelete = file
                                        showingDeleteAlert = true
                                    },
                                    onMove: {
                                        itemToMove = file
                                        showingMoveSheet = true
                                    },
                                    onRename: {
                                        itemToRename = file
                                        newItemName = file.lastPathComponent
                                        showingRenameAlert = true
                                    },
                                    onShare: {
                                        selectedFileToShare = file
                                        shareFile()
                                    }
                                )
                            }
                        } else {
                            Button(action: {
                                if isDirectory {
                                    currentDirectory = file
                                    loadFiles()
                                } else if isAudio {
                                    onSelect(file)
                                    audioURL = file
                                }
                            }) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    onDelete: {
                                        itemToDelete = file
                                        showingDeleteAlert = true
                                    },
                                    onMove: {
                                        itemToMove = file
                                        showingMoveSheet = true
                                    },
                                    onRename: {
                                        itemToRename = file
                                        newItemName = file.lastPathComponent
                                        showingRenameAlert = true
                                    },
                                    onShare: {
                                        selectedFileToShare = file
                                        shareFile()
                                    }
                                )
                            }
                            .contextMenu {
                                shareButton(for: file)
                                deleteButton(for: file)
                                renameButton(for: file)
                                moveButton(for: file)
                            }
                        }
                    }
                }
            }
            .navigationTitle(currentDirectory?.lastPathComponent ?? "音频文件")
            .navigationDestination(for: URL.self) { url in
                if url.pathExtension.lowercased() == "pdf" {
                    PDFViewer(url: url)
                } else {
                    VideoPlayerView(
                        videoURL: url,
                        onSave: {
                            navigationPath.removeLast()
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewFolderAlert = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("新建文件夹", isPresented: $showingNewFolderAlert) {
                TextField("文件夹名称", text: $newFolderName)
                Button("取消", role: .cancel) {
                    newFolderName = ""
                }
                Button("创建") {
                    if !newFolderName.isEmpty {
                        AudioFileManager.shared.createFolder(
                            named: newFolderName,
                            at: currentDirectory
                        )
                        newFolderName = ""
                        loadFiles()
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    if let url = itemToDelete {
                        let isDirectory = AudioFileManager.shared.isDirectory(url: url)
                        AudioFileManager.shared.delete(url)
                        
                        // 如果删除的是当前文件夹，返回上级目录
                        if isDirectory && url == currentDirectory {
                            currentDirectory = url.deletingLastPathComponent()
                        }
                        loadFiles()
                    }
                }
            } message: {
                if let url = itemToDelete {
                    let isDirectory = AudioFileManager.shared.isDirectory(url: url)
                    Text("确定要删除\(isDirectory ? "文件夹" : "文件"): \(url.lastPathComponent) 吗？\(isDirectory ? "\n注意：文件夹内的所有内容都将被删除" : "")")
                }
            }
            .alert("重命名", isPresented: $showingRenameAlert) {
                TextField("新名称", text: $newItemName)
                Button("取消", role: .cancel) {
                    newItemName = ""
                    itemToRename = nil
                }
                Button("确定") {
                    if let url = itemToRename,
                       !newItemName.isEmpty {
                        do {
                            // 如果是文件，保持扩展名
                            let newName = AudioFileManager.shared.isDirectory(url: url)
                                ? newItemName
                                : newItemName.hasSuffix(".mp3") || newItemName.hasSuffix(".mp4")
                                    ? newItemName
                                    : newItemName + (url.pathExtension.isEmpty ? "" : "." + url.pathExtension)
                        
                        try AudioFileManager.shared.rename(url, to: newName)
                        newItemName = ""
                        itemToRename = nil
                        loadFiles()
                    } catch {
                        print("Error renaming item: \(error)")
                    }
                }
            }
            } message: {
                if let url = itemToRename {
                    Text("将\(AudioFileManager.shared.isDirectory(url: url) ? "文件夹" : "文件"): \(url.lastPathComponent) 重命名为:")
                }
            }
            .sheet(isPresented: $showingMoveSheet) {
                FolderPickerView(
                    currentDirectory: nil,
                    selectedFolder: $selectedDestination,
                    excludeURL: itemToMove
                )
                .onChange(of: selectedDestination) { newValue in
                    if let destination = newValue,
                       let source = itemToMove {
                        do {
                            try AudioFileManager.shared.moveFile(source, to: destination)
                        } catch {
                            print("Error moving file: \(error)")
                        }
                        selectedDestination = nil
                        showingMoveSheet = false
                        itemToMove = nil
                        loadFiles()
                    }
                }
            }
        }
        .onAppear(perform: loadFiles)
        .onReceive(NotificationCenter.default.publisher(for: AudioFileManager.folderChangedNotification)) { _ in
            loadFiles()
        }
    }
    
    private func loadFiles() {
        files = AudioFileManager.shared.getContents(at: currentDirectory)
    }
    
    private func formatFileDate(for file: URL) -> String {
        do {
            let resources = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let date = resources.contentModificationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } catch {
            print("Error getting file date: \(error)")
        }
        return ""
    }
    
    private func getFileIcon(isDirectory: Bool, isVideo: Bool) -> String {
        if isDirectory {
            return "folder"
        } else if isVideo {
            return "video"
        } else {
            return "music.note"
        }
    }
    
    private func shareButton(for file: URL) -> some View {
        Button(action: {
            selectedFileToShare = file
            shareFile()
        }) {
            Label("分享", systemImage: "square.and.arrow.up")
        }
    }
    
    private func deleteButton(for file: URL) -> some View {
        Button(role: .destructive, action: {
            itemToDelete = file
            showingDeleteAlert = true
        }) {
            Label("删除", systemImage: "trash")
        }
    }
    
    private func renameButton(for file: URL) -> some View {
        Button(action: {
            itemToRename = file
            newItemName = file.lastPathComponent
            showingRenameAlert = true
        }) {
            Label("重命名", systemImage: "pencil")
        }
    }
    
    private func moveButton(for file: URL) -> some View {
        Button(action: {
            itemToMove = file
            showingMoveSheet = true
        }) {
            Label("移动到...", systemImage: "folder")
        }
    }
    
    private func shareFile() {
        guard let fileToShare = selectedFileToShare else { return }
        let activityViewController = UIActivityViewController(activityItems: [fileToShare], applicationActivities: nil)
        
        // Function to find the top-most view controller
        func topViewController(from viewController: UIViewController?) -> UIViewController {
            if let navigationController = viewController as? UINavigationController {
                return topViewController(from: navigationController.visibleViewController)
            }
            if let tabBarController = viewController as? UITabBarController {
                return topViewController(from: tabBarController.selectedViewController)
            }
            if let presented = viewController?.presentedViewController {
                return topViewController(from: presented)
            }
            return viewController!
        }

        // Get the top-most view controller to present the UIActivityViewController
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let topVC = topViewController(from: rootViewController)
            topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
}

// 添加文件夹选择器视图
struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var currentDirectory: URL?
    @Binding var selectedFolder: URL?
    var excludeURL: URL?
    
    @State private var files: [URL] = []
    
    var body: some View {
        NavigationView {
            List {
                if let current = currentDirectory {
                    Button(action: {
                        selectedFolder = current.deletingLastPathComponent()
                    }) {
                        HStack {
                            Image(systemName: "arrow.backward")
                            Text("选择当前文件夹")
                        }
                    }
                }
                
                ForEach(files, id: \.self) { url in
                    if url != excludeURL && AudioFileManager.shared.isDirectory(url: url) {
                        Button(action: {
                            selectedFolder = url
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                Text(url.lastPathComponent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择目标文件夹")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadFolders()
        }
    }
    
    private func loadFolders() {
        files = AudioFileManager.shared.getContents(at: currentDirectory)
    }
}

// 添加文件行视图组件
struct FileRowView: View {
    let url: URL
    let isDirectory: Bool
    let isVideo: Bool
    var onDelete: () -> Void
    var onMove: () -> Void
    var onRename: () -> Void
    var onShare: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: getFileIcon(isDirectory: isDirectory, isVideo: isVideo))
                .foregroundColor(isDirectory ? .blue : (isVideo ? .red : .blue))
            VStack(alignment: .leading) {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                if !isDirectory {
                    Text(formatFileDate(for: url))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if !isDirectory {
                Image(systemName: isVideo ? "play.rectangle.fill" : "play.circle.fill")
                    .foregroundColor(isVideo ? .red : .blue)
                    .font(.title2)
            }
        }
        .contextMenu {
            if isDirectory {
                Button(role: .destructive, action: onDelete) {
                    Label("删除文件夹", systemImage: "trash")
                }
            } else {
                Button(action: onShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                
                Button(action: onMove) {
                    Label("移动到...", systemImage: "folder")
                }
                
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label(isVideo ? "删除视频" : "删除文件", systemImage: "trash")
                }
            }
        }
    }
    
    private func getFileIcon(isDirectory: Bool, isVideo: Bool) -> String {
        if isDirectory {
            return "folder"
        } else if isVideo {
            return "video"
        } else {
            return "music.note"
        }
    }
    
    private func formatFileDate(for file: URL) -> String {
        do {
            let resources = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let date = resources.contentModificationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } catch {
            print("Error getting file date: \(error)")
        }
        return ""
    }
} 
