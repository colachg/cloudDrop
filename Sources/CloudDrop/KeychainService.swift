import Foundation

struct R2Credentials: Codable, Equatable {
    let accountId: String
    let accessKeyId: String
    let secretAccessKey: String
    let apiToken: String
}

struct AppData: Codable {
    var credentials: R2Credentials?
    var buckets: [String] = []
    var selectedBucket: String = ""
    var publicURLBase: String = ""
    var recentUploads: [RecentUpload] = []
    var defaultUploadPrefix: String = ""
}

@MainActor
final class Storage {
    static let shared = Storage()

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("CloudDrop")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    func load() -> AppData {
        guard let data = try? Data(contentsOf: fileURL),
              let appData = try? JSONDecoder().decode(AppData.self, from: data) else {
            return AppData()
        }
        return appData
    }

    func save(_ appData: AppData) {
        guard let data = try? JSONEncoder().encode(appData) else { return }
        try? data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
    }
}
