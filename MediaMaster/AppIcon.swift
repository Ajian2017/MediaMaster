import SwiftUI

struct AppIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(red: 0.5, green: 0.2, blue: 0.8), // 浅紫色
                    Color(red: 0.3, green: 0.1, blue: 0.6)  // 深紫色
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 图标
            Image(systemName: "photo.stack.fill")
                .resizable()
                .scaledToFit()
                .padding(size * 0.25)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

// 修改预览部分
#Preview {
    VStack(spacing: 20) {
        // 小尺寸预览
        VStack {
            Text("预览尺寸")
                .font(.caption)
            AppIcon(size: 100)
        }
        
        // 导出尺寸预览
        VStack {
            Text("导出图标 (右键选择 Export)")
                .font(.caption)
            IconExport()
                .frame(width: 200, height: 200) // 预览时缩小显示
        }
    }
    .padding()
}

// 用于导出的视图
struct IconExport: View {
    var body: some View {
        AppIcon(size: 1024)
            .frame(width: 1024, height: 1024)
    }
} 