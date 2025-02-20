import SwiftUI

class FileUtil {
    class func shareFile(_ selectedFileToShare: URL?) {
        guard let fileToShare = selectedFileToShare else { return }
        let activityViewController = UIActivityViewController(activityItems: [fileToShare], applicationActivities: nil)
        
        // Function to find the top-most view controller
        func topViewController(from viewController: UIViewController?) -> UIViewController {
            if let navigationController = viewController as? UINavigationController {
                return topViewController(from: navigationController.visibleViewController)
            }
            if let tabBarController = viewController as? UITabBarController {
                return topViewController(from: tabBarController.selectedViewController)
            }
            if let presented = viewController?.presentedViewController {
                return topViewController(from: presented)
            }
            return viewController!
        }

        // Get the top-most view controller to present the UIActivityViewController
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let topVC = topViewController(from: rootViewController)
            topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
}
