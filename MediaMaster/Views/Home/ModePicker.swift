import SwiftUI

struct ModePicker: View {
    @Binding var isVideoMode: Bool
    
    var body: some View {
        Picker("模式选择", selection: $isVideoMode) {
            Text("照片").tag(false)
            Text("视频").tag(true)
        }
        .pickerStyle(.segmented)
        .padding()
    }
} 