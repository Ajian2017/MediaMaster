import Photos

class PhotoLibraryManager {
    static func saveVideoToAlbum(url: URL) async -> (success: Bool, error: Error?) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            return (false, NSError(domain: "PhotoLibraryError", code: -1, userInfo: [NSLocalizedDescriptionKey: "需要相册访问权限"]))
        }
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }
} 