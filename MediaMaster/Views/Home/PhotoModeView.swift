import SwiftUI
import PhotosUI
import PDFKit

struct PhotoModeView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @State private var selectedImages: [UIImage] = []
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var inputDirectory: URL?
    @State private var imagesCopied = false
    
    var body: some View {
        VStack {
            if selectedImages.isEmpty {
                ContentUnavailableView(
                    "暂无照片",
                    systemImage: "photo.on.rectangle",
                    description: Text("点击下方按钮选择照片")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        ForEach(selectedImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(EdgeInsets(top: 0,leading: 0,bottom: 0,trailing: 2))
                        }
                    }
                    .padding()
                }
                
                Button(action: createAndSharePDF) {
                    Label("生成PDF", systemImage: "doc.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                Button(action: copyImagesToInputFolder) {
                    Label("复制到文件中心", systemImage: "folder.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(imagesCopied ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(imagesCopied)
                .alert(isPresented: $imagesCopied) {
                    Alert(title: Text("复制完成"), message: Text("所有图片已成功复制到文件中心。"), dismissButton: .default(Text("确定")))
                }
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                selectedImages = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfData = pdfData {
                ShareSheet(items: [pdfData])
                    .onAppear {
                        print("ShareSheet is now appearing.")
                    }
            } else {
                Text("PDF data is unavailable.")
                    .padding()
            }
        }.onChange(of: pdfData) { _, newPdfData in
            if newPdfData != nil {
                showingShareSheet = true
            }
        }
        .onAppear {
            inputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(Constants.inputDirectoryName)
        }
    }
    
    private func createAndSharePDF() {
        let pdfDocument = PDFDocument()

        for (index, image) in selectedImages.enumerated() {
            if let page = PDFPage(image: image) {
                pdfDocument.insert(page, at: index)
            }
        }

        if let data = pdfDocument.dataRepresentation() {
            print("PDF data generated successfully.")
            pdfData = data  // Update pdfData
        } else {
            print("Failed to generate PDF data.")
            showingShareSheet = false  // Reset the flag if PDF data generation fails
        }
    }

    private func copyImagesToInputFolder() {
        guard let inputDirectory = inputDirectory else { return }
        
        for image in selectedImages {
            if let data = image.pngData() {
                let fileName = UUID().uuidString + ".png"
                let fileURL = inputDirectory.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: fileURL)
                    print("Image copied to: \(fileURL)")
                } catch {
                    print("Error copying image: \(error)")
                }
            }
        }
        imagesCopied = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
