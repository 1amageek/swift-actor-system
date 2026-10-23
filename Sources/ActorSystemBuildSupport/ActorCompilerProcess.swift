import ActorSystemGeneration
import Foundation

/// Captures compiler output without blocking a child on a full pipe.
enum ActorCompilerProcess {
    struct Output {
        let status: Int32
        let standardOutput: Data
        let standardError: Data
    }

    static func run(
        executable: URL,
        arguments: [String],
        combineOutput: Bool = false
    ) throws -> Output {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("actor-compiler-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                // Temporary cleanup does not change the compiler's result.
            }
        }
        let stdoutURL = directory.appendingPathComponent("stdout")
        let stderrURL = directory.appendingPathComponent("stderr")
        try Data().write(to: stdoutURL)
        try Data().write(to: stderrURL)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            do {
                try stdout.close()
                try stderr.close()
            } catch {
                // Child exit and output reads remain the authoritative result.
            }
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = combineOutput ? stdout : stderr
        try process.run()
        process.waitUntilExit()
        return Output(
            status: process.terminationStatus,
            standardOutput: try Data(contentsOf: stdoutURL),
            standardError: try Data(contentsOf: stderrURL)
        )
    }
}
