import Foundation
import UniformTypeIdentifiers
import WebKit

final class WebUISchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    static let scheme = "genimage-ui"
    static let host = "app"

    private let resourceRoot: URL?

    override init() {
        resourceRoot = Bundle.module.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebUI"
        )?.deletingLastPathComponent().standardizedFileURL
        super.init()
    }

    var canServeResources: Bool {
        resourceRoot != nil
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              requestURL.scheme == Self.scheme,
              requestURL.host == Self.host,
              let resourceRoot,
              let relativePath = normalizedRelativePath(from: requestURL) else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let fileURL = resourceRoot
            .appendingPathComponent(relativePath, isDirectory: false)
            .standardizedFileURL
        let rootPath = resourceRoot.path.hasSuffix("/")
            ? resourceRoot.path
            : resourceRoot.path + "/"

        guard fileURL.path.hasPrefix(rootPath),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let contentType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                ?? fallbackMIMEType(for: fileURL.pathExtension)
            let response = URLResponse(
                url: requestURL,
                mimeType: contentType,
                expectedContentLength: data.count,
                textEncodingName: isTextContent(fileURL.pathExtension) ? "utf-8" : nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private func normalizedRelativePath(from url: URL) -> String? {
        let decoded = url.path.removingPercentEncoding ?? url.path
        let path = decoded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty,
              !path.split(separator: "/").contains("..") else {
            return nil
        }
        return path
    }

    private func fallbackMIMEType(for extensionName: String) -> String {
        switch extensionName.lowercased() {
        case "js": "text/javascript"
        case "css": "text/css"
        case "html": "text/html"
        case "json": "application/json"
        case "svg": "image/svg+xml"
        default: "application/octet-stream"
        }
    }

    private func isTextContent(_ extensionName: String) -> Bool {
        ["js", "css", "html", "json", "svg"].contains(extensionName.lowercased())
    }
}
