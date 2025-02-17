import SwiftUI

struct PDFFileView: View {
    let url: URL
    
    var body: some View {
        HStack {
            Image(systemName: "doc.plaintext") // Use a PDF icon
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.blue)
            
            Text(url.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
} 