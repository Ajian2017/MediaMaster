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
                        Text(file.lastPathComponent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
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
                includingPropertiesForKeys: nil
            )
            inputFiles = files.filter { $0.pathExtension.lowercased() == "mp3" }
            print("Loaded input files: \(inputFiles)")
        } catch {
            print("Error loading input files: \(error)")
        }
    }
} 