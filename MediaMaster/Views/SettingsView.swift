import SwiftUI

struct SettingsView: View {
    @AppStorage("audioTimer") private var audioTimer: Int = 0 // Store timer value in UserDefaults
    let timerOptions = [0, 1, 30, 60, 120] // Options in minutes
    @EnvironmentObject var audioViewModel: AudioPlayerViewModel // 引入 AudioPlayerViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Audio Timer Settings")) {
                    Picker("Select Timer", selection: $audioTimer) {
                        ForEach(timerOptions, id: \.self) { option in
                            Text(option == 0 ? "Off" : "\(option) minutes")
                                .tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: audioTimer) { newValue in
                        if newValue > 0 {
                            audioViewModel.startTimer(for: newValue) // 启动定时器
                        } else {
                            audioViewModel.stopTimer() // 停止定时器
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
} 
