import SwiftUI

struct FolderNode: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var name: String
    var children: [FolderNode]?
    
    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var currentDirectory: URL?
    @Binding var selectedFolder: URL?
    var excludeURL: URL?
    
    // 添加移动文件相关属性
    var fileToMove: URL? // 要移动的文件
    var onMoveComplete: (() -> Void)? // 移动完成后的回调
    
    @State private var rootNode: FolderNode?
    @State private var expandedNodes: Set<URL> = []
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let root = rootNode {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            FolderTreeNode(
                                node: root,
                                level: 0,
                                expandedNodes: $expandedNodes,
                                selectedFolder: $selectedFolder,
                                excludeURL: excludeURL,
                                fileToMove: fileToMove,
                                onMove: moveFile
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(fileToMove != nil ? "选择目标文件夹" : "选择文件夹")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            loadFolderStructure()
        }
    }
    
    private func loadFolderStructure() {
        guard let startURL = currentDirectory else { return }
        rootNode = createFolderNode(from: startURL)
        expandedNodes.insert(startURL)
    }
    
    private func createFolderNode(from url: URL) -> FolderNode {
        let contents = AudioFileManager.shared.getContents(at: url)
        let folders = contents.filter { AudioFileManager.shared.isDirectory(url: $0) }

        let children = folders.map { folderURL -> FolderNode in
            createFolderNode(from: folderURL)
        }

        return FolderNode(
            url: url,
            name: url.lastPathComponent,
            children: children.isEmpty ? nil : children
        )
    }
    
    private func moveFile(to destinationURL: URL) {
        guard let fileToMove = fileToMove else {
            selectedFolder = destinationURL
            return
        }
        
        do {
            let fileManager = FileManager.default
            let destinationPath = destinationURL.appendingPathComponent(fileToMove.lastPathComponent)
            
            // 检查目标路径是否已存在同名文件
            if fileManager.fileExists(atPath: destinationPath.path) {
                errorMessage = "目标文件夹已存在同名文件"
                showError = true
                return
            }
            
            // 执行移动操作
            try fileManager.moveItem(at: fileToMove, to: destinationPath)
            
            // 发送文件夹变更通知
            NotificationCenter.default.post(name: AudioFileManager.folderChangedNotification, object: nil)
            
            // 调用完成回调
            onMoveComplete?()
            
            // 关闭选择器
            dismiss()
            
        } catch {
            errorMessage = "移动文件失败：\(error.localizedDescription)"
            showError = true
        }
    }
}

struct FolderTreeNode: View {
    let node: FolderNode
    let level: Int
    @Binding var expandedNodes: Set<URL>
    @Binding var selectedFolder: URL?
    var excludeURL: URL?
    var fileToMove: URL?
    var onMove: ((URL) -> Void)?
    
    private var isExpanded: Bool {
        expandedNodes.contains(node.url)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if node.url != excludeURL {
                Button(action: {
                    if fileToMove != nil {
                        onMove?(node.url)
                    } else {
                        selectedFolder = node.url
                    }
                }) {
                    HStack {
                        Button(action: {
                            toggleExpansion()
                        }) {
                            Image(systemName: hasChildren ? (isExpanded ? "chevron.down" : "chevron.right") : "circle")
                                .frame(width: 20)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                        
                        Text(node.name)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if fileToMove != nil {
                            Text("移动到这里")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.leading, CGFloat(level * 20))
                .contentShape(Rectangle())
                
                if isExpanded, let children = node.children {
                    ForEach(children) { child in
                        FolderTreeNode(
                            node: child,
                            level: level + 1,
                            expandedNodes: $expandedNodes,
                            selectedFolder: $selectedFolder,
                            excludeURL: excludeURL,
                            fileToMove: fileToMove,
                            onMove: onMove
                        )
                    }
                }
            }
        }
    }
    
    private var hasChildren: Bool {
        node.children?.isEmpty == false
    }

    
    private func toggleExpansion() {
        withAnimation {
            if expandedNodes.contains(node.url) {
                expandedNodes.remove(node.url)
            } else {
                expandedNodes.insert(node.url)
            }
        }
    }
}
