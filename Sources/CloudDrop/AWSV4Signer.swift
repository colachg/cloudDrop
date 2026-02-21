import CryptoKit
import Foundation

struct AWSV4Signer: Sendable {
    let accessKeyId: String
    let secretAccessKey: String
    let region: String
    let service: String

    func sign(_ request: URLRequest, body: Data) -> URLRequest {
        var request = request
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        let payloadHash = SHA256.hash(data: body).hexString

        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        let host = request.url!.host!
        request.setValue(host, forHTTPHeaderField: "Host")

        // Canonical request
        let method = request.httpMethod ?? "GET"
        let path = request.url!.path.isEmpty ? "/" : request.url!.path

        // AWS V4 requires query params sorted by name with values URI-encoded
        let query: String
        if let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false),
           let items = components.queryItems, !items.isEmpty {
            query = items
                .map { item in
                    let name = Self.uriEncode(item.name)
                    let value = Self.uriEncode(item.value ?? "")
                    return "\(name)=\(value)"
                }
                .sorted()
                .joined(separator: "&")
        } else {
            query = ""
        }

        let signedHeaderKeys = request.allHTTPHeaderFields!.keys
            .map { $0.lowercased() }
            .sorted()
        let signedHeaders = signedHeaderKeys.joined(separator: ";")

        let canonicalHeaders = signedHeaderKeys
            .map { key in
                let value = request.allHTTPHeaderFields!.first { $0.key.lowercased() == key }!.value
                return "\(key):\(value.trimmingCharacters(in: .whitespaces))"
            }
            .joined(separator: "\n")

        let canonicalRequest = [
            method,
            path,
            query,
            canonicalHeaders,
            "",
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        // String to sign
        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8)).hexString
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            canonicalRequestHash,
        ].joined(separator: "\n")

        // Signing key
        let kDate = hmac(key: Data("AWS4\(secretAccessKey)".utf8), data: Data(dateStamp.utf8))
        let kRegion = hmac(key: kDate, data: Data(region.utf8))
        let kService = hmac(key: kRegion, data: Data(service.utf8))
        let kSigning = hmac(key: kService, data: Data("aws4_request".utf8))

        // Signature
        let signature = hmac(key: kSigning, data: Data(stringToSign.utf8)).hexString

        let authorization =
            "AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")

        return request
    }

    private func hmac(key: Data, data: Data) -> Data {
        let key = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature)
    }

    /// RFC 3986 URI-encode: only unreserved characters (A-Z a-z 0-9 - . _ ~) are left unencoded.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func uriEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? string
    }
}

extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
