#if RunningApplication && os(macOS)

import AppKit
import Darwin

public actor RunningProcessObserver {
    public enum Target: Sendable {
        case pid(pid_t)
        case name(String)
        case executablePath(String)
    }

    public let target: Target
    public let pollingInterval: TimeInterval

    private var pollingTask: Task<Void, Never>?
    private var knownPIDs: Set<pid_t> = []
    private var didLaunch: @Sendable () -> Void = {}
    private var didTerminate: @Sendable () -> Void = {}

    public init(target: Target, pollingInterval: TimeInterval = 2.0) {
        self.target = target
        self.pollingInterval = pollingInterval
    }

    public func onLaunch(_ handler: @escaping @Sendable () -> Void) {
        self.didLaunch = handler
    }

    public func onTerminate(_ handler: @escaping @Sendable () -> Void) {
        self.didTerminate = handler
    }

    public func start() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            // Initial scan
            let initialPIDs = self.findMatchingPIDs()
            await self.updateKnownPIDs(initialPIDs)

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                let currentPIDs = self.findMatchingPIDs()
                await self.diffAndNotify(currentPIDs)
            }
        }
    }

    public func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        knownPIDs = []
    }

    private func updateKnownPIDs(_ pids: Set<pid_t>) {
        knownPIDs = pids
    }

    private func diffAndNotify(_ currentPIDs: Set<pid_t>) {
        let launched = currentPIDs.subtracting(knownPIDs)
        let terminated = knownPIDs.subtracting(currentPIDs)

        if !launched.isEmpty {
            didLaunch()
        }
        if !terminated.isEmpty {
            didTerminate()
        }

        knownPIDs = currentPIDs
    }

    private nonisolated func findMatchingPIDs() -> Set<pid_t> {
        switch target {
        case .pid(let targetPID):
            return BSDProcess.isRunning(pid: targetPID) ? [targetPID] : []
        case .name(let targetName):
            return Set(BSDProcess.allPIDs().filter { BSDProcess.name(for: $0) == targetName })
        case .executablePath(let targetPath):
            return Set(BSDProcess.allPIDs().filter { BSDProcess.executablePath(for: $0) == targetPath })
        }
    }
}

#endif
