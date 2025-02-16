import SwiftUI

struct InputFileListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var audioURL: URL?
    let onSelectAudio: (URL) -> Void
    @State private var inputFiles: [URL] = []
    @State private var showingDeleteAlert = false
    @State private var fileToDelete: URL?

    var body: some View {
        NavigationView {
            List {
                ForEach(inputFiles, id: \.self) { file in
                    Button(action: {
                        audioURL = file
                        onSelectAudio(file)
                    }) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                                Text(formatFileDate(for: file))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .contentShape(Rectangle())
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            fileToDelete = file
                            showingDeleteAlert = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Input 文件夹")
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
            .onAppear(perform: loadInputFiles)
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let file = fileToDelete {
                        deleteFile(at: file)
                    }
                }
            } message: {
                Text("确定要删除这个音频文件吗？")
            }
        }
    }

    private func deleteFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadInputFiles() // 重新加载文件列表
            print("Successfully deleted file: \(url.lastPathComponent)")
        } catch {
            print("Error deleting file: \(error)")
        }
    }

    private func loadInputFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let inputDirectoryURL = documentsURL.appendingPathComponent("Input")

        do {
            let files = try fileManager.contentsOfDirectory(
                at: inputDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            inputFiles = files
                .filter { $0.pathExtension.lowercased() == "mp3" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let date2 = try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return date1 ?? Date() > date2 ?? Date()
                }
            print("Loaded input files: \(inputFiles)")
        } catch {
            print("Error loading input files: \(error)")
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