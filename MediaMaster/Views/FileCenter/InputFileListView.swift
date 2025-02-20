import SwiftUI
import LocalAuthentication

struct InputFileListView: View {
    @Environment(\.dismiss) private var dismiss
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
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "请使用 Face ID 或 Touch ID 解锁访问文件"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let current = currentDirectory, current.lastPathComponent != Constants.inputDirectoryName {
                    backButton(current: current)
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
                        let isImage = file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "png"
                        
                        if isVideo {
                            NavigationLink(value: file) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    isImage: isImage,
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
                                        FileUtil.shareFile(file)
                                    }
                                )
                            }
                        } else if isImage {
                            // Add navigation for image files
                            NavigationLink(value: file) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    isImage: isImage,
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
                                        FileUtil.shareFile(file)
                                    }
                                )
                            }
                            .contextMenu {
                                shareButton(for: file)
                                deleteButton(for: file)
                                renameButton(for: file)
                                moveButton(for: file)
                            }
                        } else {
                            Button(action: {
                                if isDirectory {
                                    currentDirectory = file
                                    authenticateUser { success in
                                           if success {
                                               loadFiles()
                                               print("Access granted to profile files.")
                                           } else {
                                               // Handle authentication failure
                                               print("Access denied. Authentication failed.")
                                           }
                                       }
                                } else if isAudio {
                                    onSelect(file)
                                }
                            }) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    isImage: isImage,
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
                                        FileUtil.shareFile(file)
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
            .navigationTitle(currentDirectory?.lastPathComponent ?? "文件中心")
            .navigationDestination(for: URL.self) { url in
                if url.pathExtension.lowercased() == "pdf" {
                    PDFViewer(url: url)
                } else if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "png" {
                    // Add navigation destination for image files
                    ImagePreviewView(imageURL: url)
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
                .onChange(of: selectedDestination) { _, newValue in
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
    
    private func backButton(current: URL) -> some View {
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
        
    private func loadFiles() {
        files = AudioFileManager.shared.getContents(at: currentDirectory)
    }
        
    private func shareButton(for file: URL) -> some View {
        Button(action: {
            FileUtil.shareFile(file)
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
}
