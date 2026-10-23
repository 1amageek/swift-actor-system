@testable import ActorSystemBuildSupport
import ActorSystemGeneration
import Foundation
import Testing

@Suite
struct ActorCompilerProcessTests {
    @Test
    func resolverCapturesLargeStandardErrorWithoutBlocking() throws {
        let script = try makeCompilerScript("""
        if [ "$1" = "-print-target-info" ]; then
            head -c 1048576 /dev/zero >&2
            printf '%s' '{"compilerVersion":"Swift version 6.4","target":{"unversionedTriple":"arm64-apple-macos"}}'
        fi
        """)
        defer { removeScript(script) }
        let environment = try ActorCompilerTargetEnvironmentResolver.resolve(
            swiftCompiler: script,
            availableModules: [],
            atomicBitWidthCandidates: []
        )
        #expect(environment.architecture == "arm64")
        #expect(environment.compilerVersion == [6, 4])
    }

    @Test
    func capturesLargeSeparateStreamsAndExitStatus() throws {
        let result = try ActorCompilerProcess.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "head -c 1048576 /dev/zero >&2; head -c 1048576 /dev/zero; exit 23"]
        )
        #expect(result.status == 23)
        #expect(result.standardOutput == Data(repeating: 0, count: 1_048_576))
        #expect(result.standardError == Data(repeating: 0, count: 1_048_576))
    }

    @Test
    func combinedOutputPreservesWriteOrder() throws {
        let result = try ActorCompilerProcess.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "printf first; printf second >&2; printf third"],
            combineOutput: true
        )
        #expect(result.status == 0)
        #expect(String(decoding: result.standardOutput, as: UTF8.self) == "firstsecondthird")
        #expect(result.standardError.isEmpty)
    }

    @Test
    func launchFailurePropagates() {
        #expect(throws: (any Error).self) {
            try ActorCompilerProcess.run(
                executable: URL(fileURLWithPath: "/nonexistent/actor-compiler"),
                arguments: []
            )
        }
    }

    @Test
    func resolverPreservesCompilerFailureStatusAndDiagnostics() throws {
        let script = try makeCompilerScript("printf 'compiler rejected target' >&2; exit 29")
        defer { removeScript(script) }
        do {
            _ = try ActorCompilerTargetEnvironmentResolver.resolve(swiftCompiler: script, availableModules: [])
            Issue.record("Expected compiler failure")
        } catch ActorGenerationError.toolchainFailure(_, let status, let output) {
            #expect(status == 29)
            #expect(output == "compiler rejected target")
        }
    }

    private func makeCompilerScript(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("actor-compiler-test-\(UUID().uuidString)")
        try ("#!/bin/sh\nset -eu\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func removeScript(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("Cannot remove compiler fixture: \(error)")
        }
    }
}
