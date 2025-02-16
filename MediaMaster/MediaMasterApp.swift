//
//  MediaMasterApp.swift
//  MediaMaster
//
//  Created by Amob on 2025/2/13.
//

import SwiftUI

@main
struct MediaMasterApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 处理文件打开
        NotificationCenter.default.post(name: NSNotification.Name("OpenAudioFile"), object: url)
        return true
    }
}
