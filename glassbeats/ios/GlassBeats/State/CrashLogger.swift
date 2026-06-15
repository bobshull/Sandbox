import Foundation
import Darwin

// Pre-allocated globals — signal handlers can only touch these
private let _btBuffer: UnsafeMutablePointer<UnsafeMutableRawPointer?> = {
    let p = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 64)
    p.initialize(repeating: nil, count: 64)
    return p
}()
private let _crashLogPath: UnsafeMutablePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: Int(PATH_MAX))
    p.initialize(repeating: 0, count: Int(PATH_MAX))
    return p
}()
private let _crashHeader: UnsafeMutablePointer<CChar> = {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: 256)
    p.initialize(repeating: 0, count: 256)
    return p
}()
private var _crashHeaderLen: Int = 0

func _glassBeatsCrashSignalHandler(_ sig: Int32) {
    signal(sig, SIG_DFL)
    let fd = open(_crashLogPath, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    if fd >= 0 {
        _ = write(fd, _crashHeader, _crashHeaderLen)
        let count = backtrace(_btBuffer, 64)
        backtrace_symbols_fd(_btBuffer, count, fd)
        _ = Darwin.close(fd)
    }
    raise(sig)
}

final class CrashLogger {
    static let shared = CrashLogger()

    static let logURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("crash_report.txt")
    }()

    private init() {}

    func install() {
        let info = Bundle.main.infoDictionary
        let v = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let b = (info?["CFBundleVersion"] as? String) ?? "?"

        // Populate signal handler globals before installing handlers
        Self.logURL.path.withCString { _ = strlcpy(_crashLogPath, $0, Int(PATH_MAX)) }
        let header = "GlassBeats \(v) (\(b))\nDate: \(Date())\n\nBacktrace:\n"
        header.withCString { _ = strlcpy(_crashHeader, $0, 256) }
        _crashHeaderLen = min(strlen(_crashHeader), 255)

        // ObjC/bridged Swift exception handler
        NSSetUncaughtExceptionHandler { exc in
            // Disable signal handlers so the subsequent SIGABRT doesn't overwrite this report
            for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS] { signal(sig, SIG_DFL) }

            let info = Bundle.main.infoDictionary
            let v = (info?["CFBundleShortVersionString"] as? String) ?? "?"
            let b = (info?["CFBundleVersion"] as? String) ?? "?"
            let report = [
                "GlassBeats \(v) (\(b))",
                "Date: \(Date())",
                "",
                "Exception: \(exc.name.rawValue)",
                "Reason: \(exc.reason ?? "none")",
                "",
                "Stack:",
                exc.callStackSymbols.joined(separator: "\n"),
            ].joined(separator: "\n")
            try? report.write(to: CrashLogger.logURL, atomically: false, encoding: .utf8)
        }

        // Signal handler for Swift runtime fatal errors (force-unwrap, out-of-bounds, etc.)
        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS] {
            signal(sig, _glassBeatsCrashSignalHandler)
        }
    }

    var crashLogData: Data? {
        guard FileManager.default.fileExists(atPath: Self.logURL.path) else { return nil }
        return try? Data(contentsOf: Self.logURL)
    }

    func clearLog() {
        try? FileManager.default.removeItem(at: Self.logURL)
    }
}
