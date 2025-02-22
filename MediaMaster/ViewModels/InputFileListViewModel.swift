import SwiftUI
import LocalAuthentication

class InputFileListViewModel: ObservableObject {
    @Published var currentDirectory: URL? {
        didSet {
            loadFiles() // 当 currentDirectory 被设置时，自动加载文件
        }
    }
    @Published var files: [URL] = []
    @Published var showingNewFolderAlert = false
    @Published var showingDeleteAlert = false
    @Published var itemToDelete: URL?
    @Published var newFolderName = ""
    @Published var showingMoveSheet = false
    @Published var itemToMove: URL?
    @Published var selectedDestination: URL?
    @Published var showingRenameAlert = false
    @Published var itemToRename: URL?
    @Published var newItemName = ""
    
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

    func loadFiles() {
        guard let directory = currentDirectory else { 
            print("Current directory is nil") // Debugging line
            return 
        }
        files = AudioFileManager.shared.getContents(at: directory)
        print("Loaded files: \(files)") // Debugging line
    }

    func createFolder() {
        guard let directory = currentDirectory, !newFolderName.isEmpty else { return }
        AudioFileManager.shared.createFolder(named: newFolderName, at: directory)
        newFolderName = ""
        loadFiles()
    }

    func deleteFile() {
        guard let url = itemToDelete else { return }
        let isDirectory = AudioFileManager.shared.isDirectory(url: url)
        AudioFileManager.shared.delete(url)

        // If deleting the current directory, go back to the parent directory
        if isDirectory && url == currentDirectory {
            currentDirectory = url.deletingLastPathComponent()
        }
        loadFiles()
    }

    func renameFile() {
        guard let url = itemToRename, !newItemName.isEmpty else { return }
        do {
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

    func moveFile() {
        guard let source = itemToMove, let destination = selectedDestination else { return }
        do {
            try AudioFileManager.shared.moveFile(source, to: destination)
            selectedDestination = nil
            showingMoveSheet = false
            itemToMove = nil
            loadFiles()
        } catch {
            print("Error moving file: \(error)")
        }
    }

    func authenticateAndLoadFiles(for directory: URL) {
        currentDirectory = directory
        print("Current directory set to: \(String(describing: currentDirectory))") // Debugging line
        authenticateUser { success in
            if success {
                self.loadFiles()
                print("Access granted to profile files.")
            } else {
                print("Access denied. Authentication failed.")
            }
        }
    }
    
    func deleteItem(for file: URL) -> some View {
        Button(role: .destructive, action: {
            self.itemToDelete = file
            self.showingDeleteAlert = true
        }) {
            Label("删除", systemImage: "trash")
        }
    }
    
    func renameItem(for file: URL) -> some View {
        Button(action: {
            self.itemToRename = file
            self.newItemName = file.lastPathComponent
            self.showingRenameAlert = true
        }) {
            Label("重命名", systemImage: "pencil")
        }
    }
    
    func moveItem(for file: URL) -> some View {
        Button(action: {
            self.itemToMove = file
            self.showingMoveSheet = true
        }) {
            Label("移动到...", systemImage: "folder")
        }
    }
    
    func shareItem(for file: URL) -> some View {
        Button(action: {
            FileUtil.shareFile(file)
        }) {
            Label("分享", systemImage: "square.and.arrow.up")
        }
    }
}
