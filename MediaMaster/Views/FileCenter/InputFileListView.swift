import SwiftUI
import LocalAuthentication

struct InputFileListView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (URL) -> Void
    
    @State private var navigationPath = NavigationPath()
    @StateObject private var viewModel = InputFileListViewModel()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if let current = viewModel.currentDirectory, current.lastPathComponent != Constants.inputDirectoryName {
                    backButton(current: current)
                }
                
                ForEach(viewModel.files, id: \.self) { file in
                    if file.pathExtension.lowercased() == "pdf" {
                        PDFFileView(url: file)
                            .onTapGesture {
                                navigationPath.append(file)
                            }
                            .contextMenu {
                                viewModel.share(for: file)
                                viewModel.delete(for: file)
                                viewModel.rename(for: file)
                                viewModel.move(for: file)
                            }
                    } else {
                        let isDirectory = AudioFileManager.shared.isDirectory(url: file)
                        let isVideo = file.pathExtension.lowercased() == "mp4"
                        let isAudio = file.pathExtension.lowercased() == "mp3"
                        let isImage = file.pathExtension.lowercased() == "jpg" || file.pathExtension.lowercased() == "png"
                        
                        if isVideo || isImage {
                            NavigationLink(value: file) {
                                FileRowView(
                                    url: file,
                                    isDirectory: isDirectory,
                                    isVideo: isVideo,
                                    isImage: isImage,
                                    onDelete: {
                                        viewModel.itemToDelete = file
                                        viewModel.showingDeleteAlert = true
                                    },
                                    onMove: {
                                        viewModel.itemToMove = file
                                        viewModel.showingMoveSheet = true
                                    },
                                    onRename: {
                                        viewModel.itemToRename = file
                                        viewModel.newItemName = file.lastPathComponent
                                        viewModel.showingRenameAlert = true
                                    },
                                    onShare: {
                                        FileUtil.shareFile(file)
                                    }
                                )
                            }
                        } else {
                            Button(action: {
                                if isDirectory {
                                    viewModel.authenticateAndLoadFiles(for: file)
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
                                        viewModel.itemToDelete = file
                                        viewModel.showingDeleteAlert = true
                                    },
                                    onMove: {
                                        viewModel.itemToMove = file
                                        viewModel.showingMoveSheet = true
                                    },
                                    onRename: {
                                        viewModel.itemToRename = file
                                        viewModel.newItemName = file.lastPathComponent
                                        viewModel.showingRenameAlert = true
                                    },
                                    onShare: {
                                        FileUtil.shareFile(file)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.currentDirectory?.lastPathComponent ?? "文件中心")
            .navigationDestination(for: URL.self) { url in
                if url.pathExtension.lowercased() == "pdf" {
                    PDFViewer(url: url)
                } else if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "png" {
                    ImagePreviewView(imageURL: url)
                } else {
                    VideoPlayerView(
                        videoURL: url,
                        onSave: {
                            viewModel.currentDirectory = nil
                            viewModel.loadFiles()
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showingNewFolderAlert = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .alert("新建文件夹", isPresented: $viewModel.showingNewFolderAlert) {
                TextField("文件夹名称", text: $viewModel.newFolderName)
                Button("取消", role: .cancel) {
                    viewModel.newFolderName = ""
                }
                Button("创建") {
                    viewModel.createFolder()
                }
            }
            .alert("确认删除", isPresented: $viewModel.showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    viewModel.deleteFile()
                }
            } message: {
                if let url = viewModel.itemToDelete {
                    let isDirectory = AudioFileManager.shared.isDirectory(url: url)
                    Text("确定要删除\(isDirectory ? "文件夹" : "文件"): \(url.lastPathComponent) 吗？\(isDirectory ? "\n注意：文件夹内的所有内容都将被删除" : "")")
                }
            }
            .alert("重命名", isPresented: $viewModel.showingRenameAlert) {
                TextField("新名称", text: $viewModel.newItemName)
                Button("取消", role: .cancel) {
                    viewModel.newItemName = ""
                    viewModel.itemToRename = nil
                }
                Button("确定") {
                    viewModel.renameFile()
                }
            } message: {
                if let url = viewModel.itemToRename {
                    Text("将\(AudioFileManager.shared.isDirectory(url: url) ? "文件夹" : "文件"): \(url.lastPathComponent) 重命名为:")
                }
            }
            .sheet(isPresented: $viewModel.showingMoveSheet) {
                FolderPickerView(
                    currentDirectory: nil,
                    selectedFolder: $viewModel.selectedDestination,
                    excludeURL: viewModel.itemToMove
                )
                .onChange(of: viewModel.selectedDestination) { _, newValue in
                    viewModel.moveFile()
                }
            }
        }
        .onAppear {
            viewModel.currentDirectory = AudioFileManager.shared.inputDirectoryURL
        }
        .onReceive(NotificationCenter.default.publisher(for: AudioFileManager.folderChangedNotification)) { _ in
            viewModel.loadFiles()
        }
    }
    
    private func backButton(current: URL) -> some View {
        Button(action: {
            viewModel.currentDirectory = current.deletingLastPathComponent()
            viewModel.loadFiles()
        }) {
            HStack {
                Image(systemName: "arrow.backward")
                Text("返回上级")
            }
        }
    }
}
