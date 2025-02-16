import SwiftUI

struct InputFileListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var audioURL: URL?
    @Binding var showingAudioPlayer: Bool
    @State private var inputFiles: [URL] = []

    var body: some View {
        NavigationView {
            List(inputFiles, id: \.self) { file in
                Button(action: {
                    audioURL = file
                    showingAudioPlayer = true
                    dismiss()
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
            }
            .navigationTitle("Input 文件夹")
            .navigationBarItems(trailing: Button("关闭") {
                dismiss()
            })
            .onAppear(perform: loadInputFiles)
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