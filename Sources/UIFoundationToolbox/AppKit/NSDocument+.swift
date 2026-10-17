#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

/// `async` spellings of the NSDocument operations that report back through a delegate, a selector
/// and a context pointer.
///
/// Each one runs the same NSDocument method -- panels, sheets and alerts included -- and returns
/// the `Bool` NSDocument passes to the selector. The name is the original's minus those three
/// parameters.
///
/// The operations that take a completion handler need nothing here: Swift already imports them as
/// `async` (`save(to:ofType:for:)`, `autosave(withImplicitCancellability:)`, `move(to:)`, …).
extension FrameworkToolbox where Base: NSDocument {
    /// `canClose(withDelegate:shouldClose:contextInfo:)`: settles unsaved changes, and returns
    /// whether the document may close.
    ///
    /// A document that autosaves in place and has a file is autosaved; any other edited document
    /// asks the user whether to save, discard or cancel. An unedited document returns `true` at
    /// once.
    @MainActor
    public func canClose() async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.canClose(withDelegate: delegate, shouldClose: selector, contextInfo: nil)
        }
    }

    /// `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)`: whether
    /// `windowController` may close, settling unsaved changes the way ``canClose()`` does when
    /// closing it closes the document.
    @MainActor
    public func shouldCloseWindowController(_ windowController: NSWindowController) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.shouldCloseWindowController(windowController, delegate: delegate, shouldClose: selector, contextInfo: nil)
        }
    }

    /// `save(withDelegate:didSave:contextInfo:)`: File > Save. Saves in place, or presents a save
    /// panel when the document has no file yet. Returns whether the document was saved; NSDocument
    /// has already presented the error when it was not.
    @MainActor
    public func save() async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.save(withDelegate: delegate, didSave: selector, contextInfo: nil)
        }
    }

    /// `runModalSavePanel(for:delegate:didSave:contextInfo:)`: presents a save panel for
    /// `saveOperation`, then saves. Returns whether the document was saved -- `false` when the user
    /// cancelled the panel.
    @MainActor
    public func runModalSavePanel(for saveOperation: NSDocument.SaveOperationType) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.runModalSavePanel(for: saveOperation, delegate: delegate, didSave: selector, contextInfo: nil)
        }
    }

    /// `duplicate(withDelegate:didDuplicate:contextInfo:)`: File > Duplicate. Returns whether a
    /// duplicate was made; NSDocument opens the duplicate itself.
    @MainActor
    public func duplicate() async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.duplicate(withDelegate: delegate, didDuplicate: selector, contextInfo: nil)
        }
    }

    /// `runModalPageLayout(with:delegate:didRun:contextInfo:)`: presents a page layout panel for
    /// `printInfo`. Returns whether the user accepted it.
    @MainActor
    public func runModalPageLayout(with printInfo: NSPrintInfo) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.runModalPageLayout(with: printInfo, delegate: delegate, didRun: selector, contextInfo: nil)
        }
    }

    /// `print(withSettings:showPrintPanel:delegate:didPrint:contextInfo:)`: prints the document,
    /// after the print panel when `showPrintPanel` is `true`. Returns whether it printed.
    @MainActor
    public func print(withSettings printSettings: [NSPrintInfo.AttributeKey: Any], showPrintPanel: Bool) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.print(withSettings: printSettings, showPrintPanel: showPrintPanel, delegate: delegate, didPrint: selector, contextInfo: nil)
        }
    }

    /// `runModalPrintOperation(_:delegate:didRun:contextInfo:)`: runs `printOperation`, document-
    /// modally when the document has a window. Returns whether it printed.
    @MainActor
    public func runModalPrintOperation(_ printOperation: NSPrintOperation) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .document) { delegate, selector in
            base.runModalPrintOperation(printOperation, delegate: delegate, didRun: selector, contextInfo: nil)
        }
    }

    /// `presentError(_:modalFor:delegate:didPresent:contextInfo:)`: presents `error` as a sheet on
    /// `window`. Returns whether a recovery attempt succeeded.
    @MainActor
    public func presentError(_ error: any Error, modalFor window: NSWindow) async -> Bool {
        await DocumentCallbackTrampoline.wait(for: .errorPresentation) { delegate, selector in
            base.presentError(error, modalFor: window, delegate: delegate, didPresent: selector, contextInfo: nil)
        }
    }
}

/// The delegate the `.box` operations above hand to NSDocument: it turns the selector NSDocument
/// sends when the operation ends into the resumption of a continuation.
@MainActor
private final class DocumentCallbackTrampoline: NSObject {
    /// The two selector shapes NSDocument calls back with.
    enum Callback {
        /// `- (void)document:(NSDocument *)document <flag>:(BOOL)flag contextInfo:(void *)contextInfo`
        /// -- every operation except error presentation.
        case document
        /// `- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo`
        case errorPresentation

        var selector: Selector {
            switch self {
            case .document:
                #selector(DocumentCallbackTrampoline.document(_:didFinish:contextInfo:))
            case .errorPresentation:
                #selector(DocumentCallbackTrampoline.didPresentError(withRecovery:contextInfo:))
            }
        }
    }

    private var continuation: CheckedContinuation<Bool, Never>?

    /// Starts an operation with a fresh trampoline as its delegate and waits for the callback.
    ///
    /// NSDocument does not retain its delegate, so the trampoline is kept alive here until the
    /// callback arrives. Every one of these operations promises the callback, cancelled or failed
    /// included -- some send it before returning.
    static func wait(
        for callback: Callback,
        _ start: (_ delegate: DocumentCallbackTrampoline, _ selector: Selector) -> Void
    ) async -> Bool {
        let trampoline = DocumentCallbackTrampoline()
        let result = await withCheckedContinuation { continuation in
            trampoline.continuation = continuation
            start(trampoline, callback.selector)
        }
        withExtendedLifetime(trampoline) {}
        return result
    }

    @objc(document:didFinish:contextInfo:)
    private func document(_ document: NSDocument, didFinish flag: Bool, contextInfo: UnsafeMutableRawPointer?) {
        finish(flag)
    }

    @objc(didPresentErrorWithRecovery:contextInfo:)
    private func didPresentError(withRecovery didRecover: Bool, contextInfo: UnsafeMutableRawPointer?) {
        finish(didRecover)
    }

    private func finish(_ flag: Bool) {
        continuation?.resume(returning: flag)
        continuation = nil
    }
}

#endif
