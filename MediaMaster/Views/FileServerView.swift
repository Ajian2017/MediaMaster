import SwiftUI

struct FileServerView: View {
    @StateObject private var server = FileServerManager()
    var body: some View {
        VStack(spacing: 20) {
            Text(server.serverURL)
                .font(.headline)
                .padding()
            
            Button("启动服务器") {
                server.startServer()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("停止服务器") {
                server.stopServer()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
