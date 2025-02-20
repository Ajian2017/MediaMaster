import SwiftUI

struct SettingsView: View {
    @AppStorage("audioTimer") private var audioTimer: Int = 30 // Default to 30 minutes
    let timerOptions = [0, 10, 20, 30, 60] // Reduced options for better display
    @EnvironmentObject var audioViewModel: AudioPlayerViewModel // 引入 AudioPlayerViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Audio Timer Settings")) {
                    Picker("Select Timer", selection: $audioTimer) {
                        ForEach(timerOptions, id: \.self) { option in
                            Text(option == 0 ? "Off" : "\(option) min")
                                .tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle()) // Compact style
                    .onChange(of: audioTimer) {_, newValue in
                        if newValue > 0 {
                            audioViewModel.startTimer(for: newValue) // 启动定时器
                        } else {
                            audioViewModel.stopTimer() // 停止定时器
                        }
                    }
                    .padding()
                    
                    // Visual feedback with line limit
                    if audioTimer > 0 {
                        Text("Timer set for \(audioTimer) minutes")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
                        Text("Timer is off")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                    
                    // Display remaining time
                    if audioViewModel.remainingTime > 0 {
                        Text("Remaining: \(TimeUtil.timeString(from: Double(audioViewModel.remainingTime)))")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
