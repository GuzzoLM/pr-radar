import AppKit
import Foundation

// File-based logger for debugging in .app bundle context
final class Log {
    static let shared = Log()
    private let fileHandle: FileHandle?
    private let path: String

    private init() {
        let logDir = NSHomeDirectory() + "/Library/Logs/pr-monitor"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        path = logDir + "/pr-monitor.log"
        FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o600])
        fileHandle = FileHandle(forWritingAtPath: path)
        fileHandle?.seekToEndOfFile()
    }

    func write(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
}

func log(_ message: String) {
    Log.shared.write(message)
    print(message)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.run()
