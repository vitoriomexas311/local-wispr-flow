import Foundation
import CryptoKit

/// Provisioning is explicit and separate from recognition. No network APIs here.
@MainActor
enum TinyModel {
    static let filename = "ggml-tiny.en-q5_1.bin"
    static let checksum = "c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b"
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LocalFlow/Models")
            .appendingPathComponent(filename)
    }
    static var helper: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/localflow-whisper") }
    private static var lastIdentity: String?
    private static var lastValid = false

    static var installed: Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              let changed = attributes[.modificationDate] as? Date else { return false }
        let identity = "\(size):\(changed.timeIntervalSince1970)"
        if identity == lastIdentity { return lastValid }
        lastIdentity = identity
        guard size.intValue > 0, size.intValue < 40_000_000,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { lastValid = false; return false }
        lastValid = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == checksum
        return lastValid
    }

    static var helperAvailable: Bool { FileManager.default.isExecutableFile(atPath: helper.path) }

    static func provision(importing source: URL?, completion: @escaping (Bool) -> Void) {
        guard let script = Bundle.main.url(forResource: "download-model", withExtension: "sh") else {
            completion(false); return
        }
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [script.path] + (source.map { [$0.path] } ?? [])
            process.environment = ["HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                                   "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL": "C"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            let passed: Bool
            do { try process.run(); process.waitUntilExit(); passed = process.terminationStatus == 0 }
            catch { passed = false }
            DispatchQueue.main.async {
                lastIdentity = nil
                completion(passed && installed)
            }
        }
    }
}
