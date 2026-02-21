import Foundation

@MainActor
@Observable
final class UploadTask: Identifiable {
    let id = UUID()
    let fileName: String
    let fileURL: URL
    var progress: Double = 0
    var isComplete = false
    var error: String?

    init(fileName: String, fileURL: URL) {
        self.fileName = fileName
        self.fileURL = fileURL
    }
}

struct S3Object: Identifiable, Hashable {
    let key: String
    let size: Int64
    let lastModified: Date
    var id: String { key }
}
