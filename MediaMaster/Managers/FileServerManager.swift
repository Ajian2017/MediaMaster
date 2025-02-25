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
                        self.generateFileList(for: fileURL) { html in
                            completion(GCDWebServerDataResponse(html: html))
                        }
                    } else if fileType == .typeRegular {
                        completion(GCDWebServerFileResponse(file: fileURL.path) ?? GCDWebServerDataResponse(html: "<h1>File inaccessible</h1>"))
                    } else {
                        completion(GCDWebServerDataResponse(html: "<h1>Unsupported file type</h1>"))
                    }
                }
            } catch {
                completion(GCDWebServerDataResponse(html: "<h1>File or directory not found</h1>"))
            }
        }
        
        // 添加文件上传处理
        webServer?.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerMultiPartFormRequest.self, processBlock: { (request) -> GCDWebServerResponse? in
            guard let multipartRequest = request as? GCDWebServerMultiPartFormRequest else {
                return GCDWebServerDataResponse(html: "<h1>Invalid request</h1>")
            }
            
            // Invoke firstFile as a closure with the form field name "file"
            guard let file = multipartRequest.firstFile(forControlName: "file") else {
                return GCDWebServerDataResponse(html: "<h1>No file uploaded</h1>")
            }
            
            let fileName = file.fileName ?? "uploaded_file"
            let destinationURL = self.inputDirectory.appendingPathComponent(fileName)
            
            do {
                var finalURL = destinationURL
                if FileManager.default.fileExists(atPath: finalURL.path) {
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let newFileName = "\(timestamp)_\(fileName)"
                    finalURL = self.inputDirectory.appendingPathComponent(newFileName)
                }
                
                try FileManager.default.moveItem(at: URL(fileURLWithPath: file.temporaryPath), to: finalURL)
                
                let html = """
                <html>
                    <body>
                        <h1>File uploaded successfully!</h1>
                        <a href="/">Back to file list</a>
                    </body>
                </html>
                """
                return GCDWebServerDataResponse(html: html)
            } catch {
                return GCDWebServerDataResponse(html: "<h1>Upload failed: \(error.localizedDescription)</h1>")
            }
        })
        
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
    
    // 生成文件列表的辅助方法（添加上传表单）
    private func generateFileList(for directory: URL, completion: @escaping (String) -> Void) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
            var html = """
            <html>
                <body>
                    <h1>Files in \(directory.lastPathComponent)</h1>
                    <!-- 文件上传表单 -->
                    <form action="/upload" method="post" enctype="multipart/form-data">
                        <input type="file" name="file">
                        <input type="submit" value="Upload File">
                    </form>
                    <ul>
            """
            
            for file in files {
                let fileName = file.lastPathComponent
                let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let path = directory.relativePath.replacingOccurrences(of: self.inputDirectory.relativePath, with: "") + "/" + fileName
                let linkPath = "/files" + (path.hasPrefix("/") ? path : "/" + path)
                html += "<li><a href=\"\(linkPath)\">\(fileName)\(isDirectory ? "/" : "")</a></li>"
            }
            html += """
                    </ul>
                </body>
            </html>
            """
            completion(html)
        } catch {
            completion("<html><body><h1>Error accessing directory</h1></body></html>")
        }
    }
}
