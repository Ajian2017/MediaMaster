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

    var fileToMove: URL? // 要移动的文件
    var onMoveComplete: (() -> Void)? // 移动完成后的回调

    @State private var rootNode: FolderNode?
    @State private var expandedNodes: Set<URL> = []
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("当前目录:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(currentDirectory?.lastPathComponent ?? "无")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding()

                Divider()

                ScrollView {
                    if let root = rootNode {
                        LazyVStack(alignment: .leading, spacing: 8) {
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

            if fileManager.fileExists(atPath: destinationPath.path) {
                errorMessage = "目标文件夹已存在同名文件"
                showError = true
                return
            }

            try fileManager.moveItem(at: fileToMove, to: destinationPath)

            NotificationCenter.default.post(name: AudioFileManager.folderChangedNotification, object: nil)

            onMoveComplete?()
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
        VStack(alignment: .leading, spacing: 8) {
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
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)

                        Text(node.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        if fileToMove != nil {
                            Text("移动到这里")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.leading, CGFloat(level * 20))
                    .padding(.vertical, 1)
                }

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
