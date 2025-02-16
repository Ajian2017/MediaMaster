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
    
    var body: some View {
        NavigationView {
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
                
                ForEach(files, id: \.self) { url in
                    let isDirectory = AudioFileManager.shared.isDirectory(url: url)
                    Button(action: {
                        if isDirectory {
                            currentDirectory = url
                            loadFiles()
                        } else if url.pathExtension.lowercased() == "mp3" {
                            onSelect(url)
                            audioURL = url
                        }
                    }) {
                        HStack {
                            Image(systemName: isDirectory ? "folder" : "music.note")
                                .foregroundColor(isDirectory ? .blue : .blue)
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
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                    }
                    .contextMenu {
                        if isDirectory {
                            Button(role: .destructive) {
                                itemToDelete = url
                                showingDeleteAlert = true
                            } label: {
                                Label("删除文件夹", systemImage: "trash")
                            }
                        } else {
                            Button {
                                itemToMove = url
                                showingMoveSheet = true
                            } label: {
                                Label("移动到...", systemImage: "folder")
                            }
                            
                            Button(role: .destructive) {
                                itemToDelete = url
                                showingDeleteAlert = true
                            } label: {
                                Label("删除文件", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(currentDirectory?.lastPathComponent ?? "音频文件")
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