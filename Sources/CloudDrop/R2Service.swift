import Foundation

enum R2Error: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from R2"
        case .httpError(let code, let message):
            "HTTP \(code): \(message)"
        case .uploadFailed(let message):
            "Upload failed: \(message)"
        }
    }
}

struct R2Service: Sendable {
    private let signer: AWSV4Signer
    private let endpoint: String
    private let accountId: String
    private let apiToken: String

    init(credentials: R2Credentials) {
        self.accountId = credentials.accountId
        self.apiToken = credentials.apiToken
        self.endpoint = "https://\(credentials.accountId).r2.cloudflarestorage.com"
        self.signer = AWSV4Signer(
            accessKeyId: credentials.accessKeyId,
            secretAccessKey: credentials.secretAccessKey,
            region: "auto",
            service: "s3"
        )
    }

    /// Resolve Account ID from an API token by calling Cloudflare /accounts endpoint.
    static func resolveAccountId(apiToken: String) async throws -> String {
        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw R2Error.invalidResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [[String: Any]],
              let first = result.first,
              let accountId = first["id"] as? String else {
            throw R2Error.invalidResponse
        }
        return accountId
    }

    func verifyCredentials() async throws -> [String] {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"

        let signed = signer.sign(request, body: Data())
        let (data, response) = try await URLSession.shared.data(for: signed)

        guard let http = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw R2Error.httpError(http.statusCode, body)
        }

        return BucketListParser.parse(data)
    }

    func uploadFile(fileURL: URL, bucket: String, key: String) async throws -> String {
        try await uploadFile(fileURL: fileURL, bucket: bucket, key: key, onProgress: nil)
    }

    func uploadFile(
        fileURL: URL, bucket: String, key: String,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let contentType = mimeType(for: fileURL.pathExtension)

        var request = URLRequest(url: URL(string: "\(endpoint)/\(bucket)/\(key)")!)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        let signed = signer.sign(request, body: data)

        let responseData: Data
        let response: URLResponse

        if let onProgress {
            let delegate = UploadDelegate(onProgress: onProgress)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }
            (responseData, response) = try await session.upload(for: signed, from: data)
        } else {
            (responseData, response) = try await URLSession.shared.upload(for: signed, from: data)
        }

        guard let http = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw R2Error.uploadFailed(body)
        }

        return key
    }

    func listPrefixes(bucket: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "\(endpoint)/\(bucket)?list-type=2&delimiter=/")!)
        request.httpMethod = "GET"

        let signed = signer.sign(request, body: Data())
        let (data, response) = try await URLSession.shared.data(for: signed)

        guard let http = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw R2Error.httpError(http.statusCode, body)
        }

        return PrefixListParser.parse(data)
    }

    struct ListResult {
        let objects: [S3Object]
        let folders: [String]
    }

    func listObjects(bucket: String, prefix: String = "") async throws -> ListResult {
        var components = URLComponents(string: "\(endpoint)/\(bucket)")!
        components.queryItems = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "delimiter", value: "/"),
        ]
        if !prefix.isEmpty {
            components.queryItems!.append(URLQueryItem(name: "prefix", value: prefix))
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let signed = signer.sign(request, body: Data())
        let (data, response) = try await URLSession.shared.data(for: signed)

        guard let http = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw R2Error.httpError(http.statusCode, body)
        }

        return CombinedListParser.parse(data)
    }

    func deleteObject(bucket: String, key: String) async throws {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        var request = URLRequest(url: URL(string: "\(endpoint)/\(bucket)/\(encodedKey)")!)
        request.httpMethod = "DELETE"

        let signed = signer.sign(request, body: Data())
        let (data, response) = try await URLSession.shared.data(for: signed)

        guard let http = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw R2Error.httpError(http.statusCode, body)
        }
    }

    /// Fetch all public domains (custom + managed r2.dev) for a bucket via Cloudflare API.
    func fetchDomains(bucket: String) async -> [String] {
        var domains: [String] = []

        // Fetch custom domains
        if let custom = try? await cloudflareAPI(path: "/r2/buckets/\(bucket)/domains/custom"),
           let domainList = custom["domains"] as? [[String: Any]] {
            for d in domainList {
                if let domain = d["domain"] as? String,
                   let status = d["status"] as? [String: Any],
                   let ownership = status["ownership"] as? String,
                   ownership == "verified" || ownership == "active" {
                    domains.append("https://\(domain)")
                }
            }
        }

        // Fetch managed r2.dev domain
        if let managed = try? await cloudflareAPI(path: "/r2/buckets/\(bucket)/domains/managed"),
           let enabled = managed["enabled"] as? Bool, enabled,
           let domain = managed["domain"] as? String {
            domains.append("https://\(domain)")
        }

        return domains
    }

    private func cloudflareAPI(path: String) async throws -> [String: Any] {
        let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw R2Error.invalidResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw R2Error.invalidResponse
        }
        return result
    }

    func publicURL(bucket: String, key: String, baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") {
            base = String(base.dropLast())
        }
        return "\(base)/\(key)"
    }

    private func mimeType(for ext: String) -> String {
        let types: [String: String] = [
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "webp": "image/webp",
            "svg": "image/svg+xml",
            "ico": "image/x-icon",
            "bmp": "image/bmp",
            "tiff": "image/tiff",
            "tif": "image/tiff",
            "pdf": "application/pdf",
            "json": "application/json",
            "xml": "application/xml",
            "zip": "application/zip",
            "gz": "application/gzip",
            "tar": "application/x-tar",
            "html": "text/html",
            "css": "text/css",
            "js": "application/javascript",
            "ts": "application/typescript",
            "txt": "text/plain",
            "csv": "text/csv",
            "md": "text/markdown",
            "mp4": "video/mp4",
            "mov": "video/quicktime",
            "mp3": "audio/mpeg",
            "wav": "audio/wav",
            "woff": "font/woff",
            "woff2": "font/woff2",
            "ttf": "font/ttf",
            "otf": "font/otf",
        ]
        return types[ext.lowercased()] ?? "application/octet-stream"
    }
}

// Minimal XML parser for S3 ListBuckets response
private final class BucketListParser: NSObject, XMLParserDelegate {
    private var buckets: [String] = []
    private var currentElement = ""
    private var currentText = ""

    static func parse(_ data: Data) -> [String] {
        let handler = BucketListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.buckets
    }

    func parser(
        _ parser: XMLParser, didStartElement element: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentElement = element
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser, didEndElement element: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        if element == "Name" && !currentText.isEmpty {
            buckets.append(currentText)
        }
    }
}

// Minimal XML parser for S3 ListObjectsV2 — parses both Contents and CommonPrefixes
private final class CombinedListParser: NSObject, XMLParserDelegate {
    private var objects: [S3Object] = []
    private var folders: [String] = []
    private var currentElement = ""
    private var currentText = ""
    private var currentKey = ""
    private var currentSize: Int64 = 0
    private var currentLastModified = Date()
    private var insideContents = false
    private var insideCommonPrefixes = false

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(_ data: Data) -> R2Service.ListResult {
        let handler = CombinedListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return R2Service.ListResult(objects: handler.objects, folders: handler.folders)
    }

    func parser(
        _ parser: XMLParser, didStartElement element: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentElement = element
        currentText = ""
        if element == "Contents" {
            insideContents = true
            currentKey = ""
            currentSize = 0
            currentLastModified = Date()
        } else if element == "CommonPrefixes" {
            insideCommonPrefixes = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser, didEndElement element: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        if insideContents {
            switch element {
            case "Key":
                currentKey = currentText
            case "Size":
                currentSize = Int64(currentText) ?? 0
            case "LastModified":
                currentLastModified = Self.dateFormatter.date(from: currentText) ?? Date()
            case "Contents":
                if !currentKey.isEmpty {
                    objects.append(S3Object(
                        key: currentKey,
                        size: currentSize,
                        lastModified: currentLastModified
                    ))
                }
                insideContents = false
            default:
                break
            }
        } else if insideCommonPrefixes {
            if element == "Prefix" && !currentText.isEmpty {
                folders.append(currentText)
            }
            if element == "CommonPrefixes" {
                insideCommonPrefixes = false
            }
        }
    }
}

// Minimal XML parser for S3 ListObjectsV2 CommonPrefixes (folders)
private final class PrefixListParser: NSObject, XMLParserDelegate {
    private var prefixes: [String] = []
    private var currentElement = ""
    private var currentText = ""
    private var insideCommonPrefixes = false

    static func parse(_ data: Data) -> [String] {
        let handler = PrefixListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.prefixes
    }

    func parser(
        _ parser: XMLParser, didStartElement element: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentElement = element
        currentText = ""
        if element == "CommonPrefixes" {
            insideCommonPrefixes = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser, didEndElement element: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        if insideCommonPrefixes && element == "Prefix" && !currentText.isEmpty {
            prefixes.append(currentText)
        }
        if element == "CommonPrefixes" {
            insideCommonPrefixes = false
        }
    }
}
