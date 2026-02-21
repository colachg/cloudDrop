import AppKit
import Foundation
import SwiftUI

struct RecentUpload: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let url: String
    let date: Date

    init(fileName: String, url: String) {
        self.id = UUID()
        self.fileName = fileName
        self.url = url
        self.date = Date()
    }
}

@MainActor
@Observable
final class AppState {
    var isConfigured = false
    var buckets: [String] = []
    var selectedBucket: String = ""
    var publicURLBase: String = ""

    var isUploading = false
    var currentUploadFileName: String = ""
    var uploadError: String?

    var recentUploads: [RecentUpload] = []
    var uploadTasks: [UploadTask] = []
    var s3Objects: [S3Object] = []
    var s3Folders: [String] = []
    var defaultUploadPrefix: String = ""
    var currentPrefix: String = ""
    var isLoadingObjects = false
    var toastMessage: String?
    var availableDomains: [String] = []
    var availableFolders: [String] = []

    private let storage = Storage.shared
    var r2Service: R2Service?

    init() {
        let data = storage.load()
        buckets = data.buckets
        selectedBucket = data.selectedBucket
        publicURLBase = data.publicURLBase
        recentUploads = data.recentUploads
        defaultUploadPrefix = data.defaultUploadPrefix
        currentPrefix = defaultUploadPrefix

        if let credentials = data.credentials {
            r2Service = R2Service(credentials: credentials)
            isConfigured = true

            if !selectedBucket.isEmpty {
                Task {
                    await fetchDomains(for: selectedBucket)
                    await fetchFolders(for: selectedBucket)
                }
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        var data = storage.load()
        data.buckets = buckets
        data.selectedBucket = selectedBucket
        data.publicURLBase = publicURLBase
        data.recentUploads = recentUploads
        data.defaultUploadPrefix = defaultUploadPrefix
        storage.save(data)
    }

    func saveCredentials(_ credentials: R2Credentials) -> Bool {
        var data = storage.load()
        data.credentials = credentials
        storage.save(data)
        return true
    }

    func loadCredentials() -> R2Credentials? {
        storage.load().credentials
    }

    func loadConfiguration() {
        guard let credentials = loadCredentials() else {
            isConfigured = false
            r2Service = nil
            return
        }
        r2Service = R2Service(credentials: credentials)
        isConfigured = true

        if !selectedBucket.isEmpty {
            Task {
                await fetchDomains(for: selectedBucket)
                await fetchFolders(for: selectedBucket)
            }
        }
    }

    func fetchDomains(for bucket: String) async {
        guard let r2 = r2Service else { return }
        let domains = await r2.fetchDomains(bucket: bucket)
        availableDomains = domains
        if let first = domains.first, publicURLBase.isEmpty {
            savePublicURLBase(first)
        }
    }

    func fetchFolders(for bucket: String) async {
        guard let r2 = r2Service else { return }
        do {
            let result = try await r2.listObjects(bucket: bucket, prefix: "")
            availableFolders = result.folders.sorted()
        } catch {
            availableFolders = []
        }
    }

    func saveBuckets(_ buckets: [String]) {
        self.buckets = buckets
        persist()
    }

    func saveSelectedBucket(_ bucket: String) {
        selectedBucket = bucket
        persist()
        Task {
            await fetchDomains(for: bucket)
            await fetchFolders(for: bucket)
        }
    }

    func savePublicURLBase(_ base: String) {
        publicURLBase = base
        persist()
    }

    func saveDefaultUploadPrefix(_ prefix: String) {
        var normalized = prefix
        if !normalized.isEmpty && !normalized.hasSuffix("/") {
            normalized += "/"
        }
        defaultUploadPrefix = normalized
        currentPrefix = normalized
        persist()
    }

    func addRecentUpload(_ upload: RecentUpload) {
        recentUploads.insert(upload, at: 0)
        if recentUploads.count > 20 {
            recentUploads = Array(recentUploads.prefix(20))
        }
        persist()
    }

    func clearRecentUploads() {
        recentUploads.removeAll()
        persist()
    }

    func resetConfiguration() {
        r2Service = nil
        isConfigured = false
        buckets = []
        selectedBucket = ""
        publicURLBase = ""
        defaultUploadPrefix = ""
        currentPrefix = ""
        availableDomains = []
        availableFolders = []
        var data = AppData()
        data.recentUploads = recentUploads
        storage.save(data)
    }

    // MARK: - Upload

    func uploadFiles(_ urls: [URL]) {
        guard let r2 = r2Service else { return }
        let prefix = currentPrefix
        let bucket = selectedBucket
        let urlBase = publicURLBase

        for url in urls {
            let uploadTask = UploadTask(fileName: url.lastPathComponent, fileURL: url)
            let taskId = uploadTask.id
            let fileName = uploadTask.fileName
            uploadTasks.insert(uploadTask, at: 0)

            Task {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let baseName = "\(UUID().uuidString.prefix(8))-\(fileName)"
                let key = prefix.isEmpty ? baseName : "\(prefix)\(baseName)"

                isUploading = true
                currentUploadFileName = fileName
                uploadError = nil

                do {
                    _ = try await r2.uploadFile(
                        fileURL: url,
                        bucket: bucket,
                        key: key,
                        onProgress: { fraction in
                            Task { @MainActor [weak self] in
                                self?.uploadTasks.first { $0.id == taskId }?.progress = fraction
                            }
                        }
                    )
                    uploadTasks.first { $0.id == taskId }?.progress = 1.0
                    uploadTasks.first { $0.id == taskId }?.isComplete = true

                    let publicURL = r2.publicURL(
                        bucket: bucket,
                        key: key,
                        baseURL: urlBase
                    )
                    let upload = RecentUpload(fileName: fileName, url: publicURL)
                    addRecentUpload(upload)
                    copyToClipboard(publicURL)
                    showToast("URL copied!")
                } catch {
                    uploadTasks.first { $0.id == taskId }?.error = error.localizedDescription
                    uploadError = "Failed to upload \(fileName): \(error.localizedDescription)"
                }

                Task {
                    try? await Task.sleep(for: .seconds(3))
                    uploadTasks.removeAll { $0.id == taskId }
                }

                let hasActive = uploadTasks.contains { !$0.isComplete && $0.error == nil }
                if !hasActive {
                    isUploading = false
                }
            }
        }
    }

    // MARK: - S3 Objects

    func loadObjects() {
        guard let r2 = r2Service, !selectedBucket.isEmpty else { return }
        isLoadingObjects = true

        Task {
            do {
                let result = try await r2.listObjects(bucket: selectedBucket, prefix: currentPrefix)
                s3Objects = result.objects
                    .filter { $0.key != currentPrefix && !$0.key.isEmpty }
                    .sorted { $0.lastModified > $1.lastModified }
                s3Folders = result.folders.sorted()
            } catch {
                uploadError = "Failed to list objects: \(error.localizedDescription)"
            }
            isLoadingObjects = false
        }
    }

    func enterFolder(_ folder: String) {
        currentPrefix = folder
        s3Objects = []
        s3Folders = []
        loadObjects()
    }

    func goBack() {
        var trimmed = currentPrefix
        if trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }
        if let lastSlash = trimmed.lastIndex(of: "/") {
            currentPrefix = String(trimmed[...lastSlash])
        } else {
            currentPrefix = ""
        }
        s3Objects = []
        s3Folders = []
        loadObjects()
    }

    func deleteObject(_ object: S3Object) {
        guard let r2 = r2Service, !selectedBucket.isEmpty else { return }

        Task {
            do {
                try await r2.deleteObject(bucket: selectedBucket, key: object.key)
                s3Objects.removeAll { $0.id == object.id }
                showToast("Deleted")
            } catch {
                uploadError = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    // MARK: - Helpers

    func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
