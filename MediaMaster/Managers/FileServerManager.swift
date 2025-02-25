import GCDWebServer

class FileServerManager: ObservableObject {
    private var webServer: GCDWebServer?
    @Published var serverURL: String = "服务器未启动"
    
    private let inputDirectory: URL = {
        return AudioFileManager.shared.inputDirectoryURL
    }()
    
    func startServer() {
        webServer = GCDWebServer()
        
        // 根路径：返回文件列表
        webServer?.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self) { (request, completion) in
            self.generateFileList(for: self.inputDirectory) { html in
                completion(GCDWebServerDataResponse(html: html))
            }
        }
        
        // 文件和文件夹路径：动态处理
        webServer?.addHandler(forMethod: "GET", pathRegex: "^/files/.*", request: GCDWebServerRequest.self) { (request, completion) in
            let relativePath = request.path.replacingOccurrences(of: "/files/", with: "")
            let fileURL = self.inputDirectory.appendingPathComponent(relativePath)
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileType = attributes[.type] as? FileAttributeType {
                    if fileType == .typeDirectory {
                        // 如果是文件夹，返回子目录的文件列表
                        self.generateFileList(for: fileURL) { html in
                            completion(GCDWebServerDataResponse(html: html))
                        }
                    } else if fileType == .typeRegular {
                        // 如果是文件，返回文件内容
                        completion(GCDWebServerFileResponse(file: fileURL.path) ?? GCDWebServerDataResponse(html: "<h1>File inaccessible</h1>"))
                    } else {
                        completion(GCDWebServerDataResponse(html: "<h1>Unsupported file type</h1>"))
                    }
                }
            } catch {
                completion(GCDWebServerDataResponse(html: "<h1>File or directory not found</h1>"))
            }
        }
        
        // 启动服务器
        do {
            try webServer?.start(options: [
                GCDWebServerOption_Port: 8080,
                GCDWebServerOption_BindToLocalhost: false
            ])
            if let url = webServer?.serverURL {
                serverURL = "访问地址: \(url)"
            }
        } catch {
            serverURL = "服务器启动失败: \(error.localizedDescription)"
        }
    }
    
    func stopServer() {
        webServer?.stop()
        serverURL = "服务器已停止"
    }
    
    // 生成文件列表的辅助方法
    private func generateFileList(for directory: URL, completion: @escaping (String) -> Void) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            var html = "<html><body><h1>Files in \(directory.lastPathComponent)</h1><ul>"
            
            for file in files {
                let fileName = file.lastPathComponent
                let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let path = directory.relativePath.replacingOccurrences(of: self.inputDirectory.relativePath, with: "") + "/" + fileName
                let linkPath = "/files" + (path.hasPrefix("/") ? path : "/" + path)
                html += "<li><a href=\"\(linkPath)\">\(fileName)\(isDirectory ? "/" : "")</a></li>"
            }
            html += "</ul></body></html>"
            completion(html)
        } catch {
            completion("<html><body><h1>Error accessing directory</h1></body></html>")
        }
    }
}
