import SwiftUI

struct FileRowView: View {
    let url: URL
    let isDirectory: Bool
    let isVideo: Bool
    let isImage: Bool
    var onDelete: () -> Void
    var onMove: () -> Void
    var onRename: () -> Void
    var onShare: () -> Void
    
    var body: some View {
        HStack {
            if isImage {
                Image(uiImage: UIImage(contentsOfFile: url.path) ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(5)
            } else {
                Image(systemName: getFileIcon(isDirectory: isDirectory, isVideo: isVideo, isImage: isImage))
                    .foregroundColor(isDirectory ? .blue : (isVideo ? .red : (isImage ? .green : .blue)))
            }
            VStack(alignment: .leading) {
                Text(url.lastPathComponent)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if !isDirectory {
                    Text(formatFileDate(for: url))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(fileSize(for: url))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if !isDirectory {
                if isVideo {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                } else if isImage {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
        }
        .contextMenu {
            if isDirectory {
                Button(role: .destructive, action: onDelete) {
                    Label("删除文件夹", systemImage: "trash")
                }
            } else {
                Button(action: onShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                
                Button(action: onMove) {
                    Label("移动到...", systemImage: "folder")
                }
                
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label(getDeleteLabel(), systemImage: "trash")
                }
            }
        }
    }
    
    private func getDeleteLabel() -> String {
        if isVideo {
            return "删除视频"
        } else if isImage {
            return "删除图片"
        } else {
            return "删除文件"
        }
    }
    
    private func getFileIcon(isDirectory: Bool, isVideo: Bool, isImage: Bool) -> String {
        if isDirectory {
            return "folder"
        } else if isVideo {
            return "video"
        } else if isImage {
            return "photo"
        } else {
            return "music.note"
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
    
    private func fileSize(for url: URL) -> String {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return "未知大小"
    }
}
