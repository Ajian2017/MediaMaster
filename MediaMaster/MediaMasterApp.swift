//
//  MediaMasterApp.swift
//  MediaMaster
//
//  Created by Amob on 2025/2/13.
//

import SwiftUI
import AVFoundation

@main
struct MediaMasterApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    AudioFileManager.shared.handleExternalAudioFile(url)
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        setupAudioSession()
        setupAppearance()
        setupDirectories()
        return true
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    private func setupAppearance() {
        // 设置导航栏样式
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // 设置标签栏样式
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    private func setupDirectories() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let inputDirectoryURL = documentsURL.appendingPathComponent(Constants.inputDirectoryName)
//        let outputDirectoryURL = documentsURL.appendingPathComponent("Output")
        
        // 创建必要的目录
        try? fileManager.createDirectory(at: inputDirectoryURL, withIntermediateDirectories: true)
//        try? fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        
        print("Documents directory: \(documentsURL.path)")
        print("Input directory: \(inputDirectoryURL.path)")
//        print("Output directory: \(outputDirectoryURL.path)")
    }
}

// 添加后台播放支持
extension MediaMasterApp {
    static var audioSessionSetupOnce: Bool = false
    
    static func setupBackgroundAudio() {
        guard !audioSessionSetupOnce else { return }
        audioSessionSetupOnce = true
        
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 开启后台播放
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // 注册远程控制事件
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Failed to setup background audio: \(error)")
        }
    }
}
