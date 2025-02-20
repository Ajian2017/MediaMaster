import SwiftUI

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
