#if RunningApplication && os(macOS)

import AppKit

public actor RunningApplicationObserver {
    public let observeApplicationBundleID: String

    private var runningApplicationsObservation: NSKeyValueObservation?
    private var isObserving = false
    private var wasRunning = false

    private var didLaunch: @Sendable () -> Void = {}
    private var didTerminate: @Sendable () -> Void = {}

    public init(observeApplicationBundleID: String) {
        self.observeApplicationBundleID = observeApplicationBundleID
    }

    public func start() {
        // Invalidate any existing observation to prevent leaks on double-start
        runningApplicationsObservation?.invalidate()
        isObserving = true
        wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == observeApplicationBundleID }

        runningApplicationsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, change in
            guard let self, let applications = change.newValue else { return }
            let isRunning = applications.contains { $0.bundleIdentifier == self.observeApplicationBundleID }
            Task {
                await self.handleRunningStateChange(isRunning: isRunning)
            }
        }
    }

    public func stop() {
        isObserving = false
        runningApplicationsObservation?.invalidate()
        runningApplicationsObservation = nil
    }

    public func onLaunch(_ handler: @escaping @Sendable () -> Void) {
        self.didLaunch = handler
    }

    public func onTerminate(_ handler: @escaping @Sendable () -> Void) {
        self.didTerminate = handler
    }

    private func handleRunningStateChange(isRunning: Bool) {
        guard isObserving else { return }
        if isRunning && !wasRunning {
            wasRunning = true
            didLaunch()
        } else if !isRunning && wasRunning {
            wasRunning = false
            didTerminate()
        }
    }
}

#endif
