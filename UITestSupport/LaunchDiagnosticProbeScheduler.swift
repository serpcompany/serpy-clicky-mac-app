import Foundation

struct LaunchDiagnosticProbeHandle: Sendable {
    fileprivate let task: Task<Void, Never>

    func cancel() {
        task.cancel()
    }

    func waitForCompletion() async {
        await task.value
    }
}

enum LaunchDiagnosticProbeScheduler {
    private static let stageNames = [
        "init-entered",
        "model-configured",
        "did-finish-launching",
        "presence-applied",
        "settings-present-returned",
        "model-start-returned",
    ]

    static func removeExistingReceipts(in root: URL) throws {
        for stage in stageNames {
            let receipt = root.appendingPathComponent("launch-stage.\(stage)")
            if FileManager.default.fileExists(atPath: receipt.path) {
                try FileManager.default.removeItem(at: receipt)
            }
        }
    }

    static func schedule(
        in root: URL,
        delaysInSeconds: [Int],
        report: @escaping @Sendable (String) -> Void = { message in
            FileHandle.standardError.write(Data(message.utf8))
        }
    ) -> [LaunchDiagnosticProbeHandle] {
        delaysInSeconds.map { delay in
            let task = Task.detached(priority: .utility) { @Sendable in
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                let reached = stageNames.filter {
                    FileManager.default.fileExists(
                        atPath: root.appendingPathComponent("launch-stage.\($0)").path
                    )
                }
                report("[DEBUG-cloud-launch] at=\(delay)s stages=\(reached.joined(separator: ","))\n")
            }
            return LaunchDiagnosticProbeHandle(task: task)
        }
    }
}
