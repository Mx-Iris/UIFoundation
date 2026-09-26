#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationToolbox

/// Sends whatever target/action pair the provider is carrying, the way AppKit would.
@discardableResult
private func sendAction(from provider: any TargetActionProvider) -> Bool {
    guard let action = provider.action, let target = provider.target else { return false }
    _ = (target as AnyObject).perform(action, with: provider)
    return true
}

/// `box.actionBlock` turns a closure into a target/action pair whose target is a trampoline object.
/// `target` is weak, so the only thing keeping that trampoline alive is an associated object — which
/// is why each block is installed inside an autorelease pool that drains before the action is sent.
@Suite("TargetActionProvider action blocks")
@MainActor
struct TargetActionProviderTests {
    @Test("an action block outlives the pool that installed it and fires with its control")
    func actionBlockFiresWithItsControl() throws {
        let button = NSButton()
        var receivedSenders: [NSButton] = []
        autoreleasepool {
            button.box.actionBlock = { sender in receivedSenders.append(sender) }
        }

        try #require(sendAction(from: button))
        #expect(receivedSenders.count == 1)
        #expect(receivedSenders.first === button)
    }

    @Test("a menu item keeps its action block the same way a control does")
    func menuItemActionBlockFires() throws {
        let menuItem = NSMenuItem()
        var fireCount = 0
        autoreleasepool {
            menuItem.box.actionBlock = { _ in fireCount += 1 }
        }

        try #require(sendAction(from: menuItem))
        #expect(fireCount == 1)
    }

    @Test("clearing the action block leaves nothing to send")
    func clearedActionBlockIsDisconnected() {
        let button = NSButton()
        button.box.actionBlock = { _ in }
        button.box.actionBlock = nil

        #expect(!sendAction(from: button))
    }
}

#endif
