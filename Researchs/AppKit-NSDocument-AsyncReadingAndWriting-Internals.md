# AppKit NSDocument Asynchronous Reading and Writing Internals

> Static analysis: macOS 27.0 AppKit and SwiftUI (arm64e), IDA Pro decompilation and disassembly of
> the archived `dyld_shared_cache_arm64e` (cache UUID `ea2c265e297c39c286467d8a2dff648a`). Every
> address below is a text address in that cache and moves between releases. SwiftUI was not in the
> whole-cache database, so a SwiftUI-only one was built for it
> (`/Volumes/DyldSharedCaches/macOS/27.0/SwiftUI.i64`).
>
> Behaviour: measured on macOS 27.2 (26B5112a) — by `AsyncDocumentTests` and the prototypes that
> preceded them, and by a minimal SwiftUI `DocumentGroup` probe app run without user interaction.
> Swift behaviour: Swift 6.4.2 (Xcode 27.2), compiler source at `b8189d766d8`.
>
> **Why this report exists.** `AsyncDocument` (`Sources/UIFoundationAppKit/Document/`) runs `async`
> code from NSDocument's synchronous reading and writing hooks. Where that is safe depends on which
> thread NSDocument calls each hook on, what it blocks while doing so, and what it still services
> while blocked — none of which the headers say. This report records those facts, the Swift
> isolation trap in concurrent opening, and how Apple's own bridge for SwiftUI fares against them.
> Decision record: `Documentations/Evolutions/0030-async-document.md`; guide:
> `Documentations/AsyncDocument.md`.

---

## 1. Saving: what holds the main thread, and what still runs

`-saveToURL:ofType:forSaveOperation:completionHandler:` (`0x185200244`) is a tail call to
`_saveToURL:…` (`0x185CD7988`), which goes through `performAsynchronousFileAccessUsingBlock:`,
`_prepareToSaveToURL:` and an asynchronous `NSFileCoordinator` to an accessor block on the main
thread (`0x185CD8AA4`). In order:

1. The undo manager's `_processEndOfEventNotification:` — open undo groups are closed.
2. **Only if `+_autosavesInPlace` is YES**: `changeCountTokenForSaveOperation:` (`0x185CD8B64`).
   See section 3.
3. The file modification date check.
4. The saver (`0x185CDB52C`):
   1. `canAsynchronouslyWriteToURL:ofType:forSaveOperation:` (`0x185CDB5A4`).
   2. `_swiftDataPrepareToSave` — an empty hook in the base class.
   3. `_blockUserInteraction`.
   4. `dispatch_async` of the writer block to `global_queue(0, 0)`. IDA labels the stub
      `dispatch_channel_async`; `ipsw dyld symaddr` resolves it to the same address as
      `dispatch_async`.
   5. `_waitForUserInteractionUnblocking` (`0x185CDB71C`).

The block is an `NSConditionLock` in the ivar `_userInteractionLock` (`+0x248`):

| Method | Address | Does |
|---|---|---|
| `_blockUserInteraction` | `0x185CD5814` | `lock; unlockWithCondition:0` |
| `_waitForUserInteractionUnblocking` | `0x185CD5894` | `lockWhenCondition:1; unlock` |
| `unblockUserInteraction` | `0x185200C60` | `lock; unlockWithCondition:1` |

The main thread waits in a pthread condition variable, so **nothing runs on it**: no run loop
source, no `DispatchQueue.main` block, no `@MainActor` job. If the writer never unblocks, the
writer block does it itself after `writeSafelyToURL:` returns (`0x185CDB970`), so the main thread
is held for the whole write.

### 1.1 The one channel NSDocument services: `continueAsynchronousWorkOnMainThreadUsingBlock:`

`continueAsynchronousWorkOnMainThreadUsingBlock:` (`0x185164B00`) hands the block to
`-[NSDocumentController _onMainThreadInvokeWorker:]` (`0x185164B8C`) on a serial queue named
"NSDocument Main Thread Unblocking":

- If `_mainThreadUnblockerStack.firstObject` exists, the block becomes a *blocking interrupter* of
  that unblocker (`enqueueBlockingInterrupter:`); otherwise it is added to
  `_mainThreadBlockingInterrupters`.
- Either way it is also scheduled with `CFRunLoopPerformBlock(main, default + NSModalPanel modes)`.
- An unblocker is pushed only while the main thread performs **synchronous file access**
  (`_performFileAccess:`, `0x185483EC0`) or a **synchronous activity** (`_performActivity:`). The
  wait loop then runs the interrupters on the main thread through
  `__INVOKING_BLOCKING_INTERRUPTER__` (`0x185482114`).
- The save path pushes no unblocker. **Interrupters do not run while the main thread is in the
  `NSConditionLock` wait above**; they run once it is released.

This is why `AsyncDocument` sends work to the main thread through this method rather than through
`DispatchQueue.main` or `MainActor`: inside NSDocument's file-access and activity waits, nothing
else reaches the main thread.

### 1.2 File access is held until the save has finished

The file-access completion and the coordinator's relinquishment both sit in the finishing block
(`0x185CDBD4C`), which runs only after `writeSafelyToURL:` has returned and the main thread has
finished the save. Until then every other save, revert or autosave of the document queues behind
it. A writer that, after unblocking, needs the main actor while the main thread has entered
synchronous file access for that document (reverting does) deadlocks: the main thread runs only
interrupters. Measured on SwiftUI in section 9.

---

## 2. How often `canAsynchronouslyWrite` is asked, and what may follow

**The saver is the only caller in AppKit.** The cache-wide stub
`objc_msgSend$canAsynchronouslyWriteToURL:ofType:forSaveOperation:` (`0x188078430`) has a single
code xref, `0x185CDB5A4`; AppKit's own selector reference (`0x1E07158D0`) has none. The saver only
asks when its first argument is true (`if (a2) canAsync = …; else canAsync = 0`). Raw-byte search
finds the selector in three more images — CoreThemeDefinition, OpusKit and SwiftUI, all NSDocument
subclasses — outside AppKit's save path.

But one save may ask **zero, one or several times**:

- **Asked again.** The saver can be re-entered within one save:
  - Silent recovery from a full disk: after the write fails, `0x185CD98B0` enters
    `_silentlyRecoverableVariantOfSavingError:resaver:`. The disk-full variant (`0x1853B5138`)
    calls `_attemptToFreeDiskSpace` on the main thread through `continueAsynchronousWork…`, then
    the resaver (`0x185CDAC94`) with `MOV W1, #1`, which calls the saver again.
  - "Save Anyway" in the "file was changed by another application" alert:
    `_errorForOverwrittenFileWithSandboxExtension:andSaver:` (`0x1853B3200`) calls the saver again
    once the user chooses. The flag it passes was not checked.
- **Never asked.** The saver is not reached when `_checkFileModificationDateBeforeSavingToURL:`
  returns NO (the alert above), when changing the type would overwrite an existing file, or when
  file coordination fails.
- **Asked, then no write.** Between the answer and `dispatch_async` there is no exit — only
  `_swiftDataPrepareToSave`, a breadcrumb and `_blockUserInteraction`. The exit is inside the writer
  block (`0x185CDB834`): it first calls `_preserveContentsIfNecessaryAfterWriting:NO …`
  (`0x185CDB8CC`) and on failure skips `writeSafelyToURL:` altogether (`CBZ W24` at
  `0x185CDB8F0`), then unblocks and finishes with the error. That step runs when the operation is
  Save or AutosaveInPlace, `preservesLocalVersions` is true, and
  `_canUseVersionBackupFileOptimization` yields a `backupFileURL`.
- **Answered NO**: the same writer block is called synchronously on the current — main — thread
  (`v15[2](v15)`), with the same preserve-then-skip branch, and finishes without unblocking.

**Consequences for `AsyncDocument`**, which takes its snapshot inside this question:

- Every answer overwrites the pending snapshot, so a re-asked save writes the newest snapshot. Edits
  between the first ask and the second are in the file but remain counted as unsaved (the token is
  from the first ask) — conservative, no data loss.
- A background writer is always preceded by its own ask, so it never collects a snapshot left by an
  earlier save. A write on the main thread — answered NO, or one of the synchronous paths in
  section 6 — discards any pending snapshot and takes a fresh one. Covered by
  `AsyncDocumentTests` ("a write NSDocument runs on the main thread takes a fresh snapshot …").
- A snapshot from an ask that was never followed by a write stays in memory until the next save.

---

## 3. The change-count token, and documents that do not autosave in place

The accessor sends `[documentClass _autosavesInPlace]` at `0x185CD8B54`; `+_autosavesInPlace`
(`0x185077BD8`) is a plain `B autosavesInPlace`. When it is NO, the `CBZ` at `0x185CD8B58` leaves
the token `nil` and `changeCountTokenForSaveOperation:` is never sent — its only call site in AppKit
is `0x185CD8B64`.

`_finishSavingToURL:ofType:forSaveOperation:changeCount:` (`0x185CD6B48`) with a `nil` token
(after reporting a bincompat event "inChangeCount is nil"):

| Operation | Change count |
|---|---|
| Save, SaveAs | `updateChangeCount:NSChangeCleared` (`0x185CD6F0C`) |
| AutosaveInPlace, AutosaveAs | `_differenceSinceSaving` and `_differenceSinceAutosaving` set to 0 |
| AutosaveElsewhere | `updateChangeCount:NSChangeAutosaved` (`0x185CD71B0`) |
| SaveTo | untouched |

With a token, `updateChangeCountWithToken:forSaveOperation:` (`0x185201460`) subtracts the token's
difference from the current one (`vsubq_s64`), so edits made after the token stay unsaved.

**So for a document that does not autosave in place, every edit made after the main thread is
unblocked and before the save finishes is marked saved — whether or not it reached the file.**
`AsyncDocument` therefore answers NO for those documents and lets NSDocument write synchronously.
Measured with the prototypes: the design that wrote asynchronously anyway lost a keystroke this way;
`AsyncDocumentTests` ("a document that does not autosave in place keeps a keystroke …") pins the
behaviour that replaced it.

---

## 4. Opening

### 4.1 Concurrent opening

On the main thread, the accessor of `_openDocumentWithContentsOfURL:…` (`0x1853F2340`) determines
the type, then `makeDocumentWithContentsOfURL:alternateContents:ofType:completionHandler:`
(`0x1853F3220`) asks `+canConcurrentlyReadDocumentsOfType:`. On YES it runs
`makeDocumentWithContentsOfURL:ofType:error:` on `_documentOpeningQueue` — an `NSOperationQueue`
named "NSDocumentController Opening", created in `-[NSDocumentController init]` (`0x184EFF760`),
its width `+_maximumNumberOfConcurrentlyOpeningDocuments`. **`-init` and `readFromURL:ofType:error:`
both run on that queue's thread.** The main thread is free meanwhile; the completion comes back with
`CFRunLoopPerformBlock(main, commonModes)`. AppKit's own `+canConcurrentlyReadDocumentsOfType:`
(`0x1853A9898`) answers NO.

### 4.2 Other paths

- `reopenDocumentForURL:…display:completionHandler:` goes through
  `makeDocumentForURL:withContentsOfURL:alternateContents:…` (`0x1853F371C`), which asks the same
  question. Whether state restoration and automatic reopening all go through it was not traced.
- `duplicateDocumentWithContentsOfURL:copying:…` (`0x1853F5FC0`) does **not** ask; it runs
  synchronously on the calling thread through `_oldMakeDuplicate…`.

### 4.3 The Versions browser — the unverified risk

`_loadDocumentForStackItem:wait:completionBlock:` (`0x185BA63B0`):

- With `wait:NO` and concurrent reading allowed, the load runs on `asyncDocumentOpeningQueue` — a
  background preload.
- Otherwise it calls `[op start]` on the calling thread — or, if the operation is already running,
  `waitUntilFinished`.
- `_prepareForStartAnimation` (`0x185BAC5E0`) loads the first item with `wait:YES`, synchronously
  on the main thread.
- The operation's `main` (`0x185BC28A0`) stores the original document (`+136`) and its
  `NSFileVersion` (`+144`) in thread-specific data, then calls
  `makeDocumentWithContentsOfURL:ofType:error:`.

If the main thread ever waits (`waitUntilFinished`) for an item a background preload is already
reading, a reader that needs the main thread — `AsyncDocument` applies there — cannot get it:
`waitUntilFinished` pushes no unblocker, so `continueAsynchronousWork…` blocks are not run.
Not reproduced; whether the first item can be one already being preloaded was not checked either.
Answering NO from `canConcurrentlyReadDocuments(ofType:)` takes the preload off the background, and
with it the race.

---

## 5. Reverting

All on the main thread.

- A document that autosaves in place: `revertDocumentToSaved:` (`0x1853AEDDC`) →
  `performActivityWithSynchronousWaiting:YES` → `_revertToVersionForTag:` or
  `_revertToDiscardRecentChanges…` → `_revertToVersion:preservingFirst:` (`0x1853ABD50`) →
  `performSynchronousFileAccessUsingBlock:` → synchronous `NSFileCoordinator` → possibly one
  synchronous write to preserve the current version → `_revertToContentsOfURL:` →
  `revertToContentsOfURL:ofType:error:` (`0x1853AF828`) → `readFromURL:ofType:error:`.
- A document that does not: `_revertToSavedThenContinue:` (`0x1853AB86C`), same threads.
- A file changed by another process: `presentedItemDidChange` (`0x18515E6CC`) only refreshes
  metadata. The reload comes from the reacquirer of `relinquishPresentedItemToWriter:`
  (`0x1853DA238`), which returns to the main thread through `continueAsynchronousWork…`
  (`0x1853DABB4`) and calls `_revertToVersion:nil preservingFirst:YES` (`0x1853DB54C`) inside file
  access.

What `revertToContentsOfURL:ofType:error:` does after `readFromURL:` (`0x1853AF940`), checked in
the disassembly:

1. `readFromURL:` returns NO → return NO; nothing below runs.
2. `_updateAfterRevertingToContentsOfOwnFileURL:ofType:` (`0x1853AF6F4`): `_resetMoveAndRenameSensing`,
   `removeAllCachedResourceValues`, `setFileURL:`, `setFileType:`, `setFileModificationDate:` (from
   `_fileModificationDateForURL:`), `_setTagNames:`, `_deleteAutosavedContents` (non-nil URL),
   `_setAutosavingError:nil`, then `_didUpdateAfterReverting = YES`.
3. `updateChangeCount:NSChangeCleared` (`0x1853AF960`).
4. If `!+_autosavesInPlace`: `[[NSDocumentController sharedDocumentController] noteNewRecentDocument:self]`.
5. If `hasUndoManager`: `[undoManager removeAllActions]`.

So the document is marked unedited and its undo stack cleared **as soon as `readFromURL:` returns
YES** — a reader that returns before applying (SwiftUI's, section 9) leaves the old contents on
screen, unedited and without undo, until the apply arrives.

---

## 6. Where NSDocument writes synchronously on the calling thread

Six call sites run `writeSafelyToURL:ofType:forSaveOperation:error:` on the caller's thread —
normally the main thread:

- block 2 of `duplicateAndReturnError:` (`0x1853C9E14`), inside `performSynchronousFileAccess` and a
  synchronous coordinated read;
- `_automaticallyDuplicate` (`0x1853B7CB8`);
- `shareDocumentWithSharingService:` (`0x1853C5744`);
- `_preserveCurrentVersionForReason:` (`0x185C6EF0C`), only with `hasUnautosavedChanges`, as
  AutosaveElsewhere;
- the legacy `_saveToURL:…error:`;
- the asynchronous save's own writer block.

`duplicateAndReturnError:` is called from save-error recovery (`_willPresentSavingError…`), the
locked-file "Duplicate" alert and Versions' `_doDuplicateRevisionDocument:`. Autosaving,
`duplicateDocumentWithDelegate:…`, move and rename all go through the asynchronous
`saveToURL:…completionHandler:` path (17 call sites). Saving at termination was not traced, but it
is not among the synchronous six.

---

## 7. `performSynchronousFileAccessUsingBlock:` keeps its `NS_NOESCAPE` block

The header declares the block `NS_NOESCAPE`, so Swift imports it as a non-escaping closure and
checks, when the call returns, that the block was released. When the method has to wait — another
file access of the same document is in progress — AppKit keeps the block past returning, and the
check traps:

```
closure argument passed as @noescape to Objective-C has escaped
```

Measured on macOS 27.2: the main thread called it while an `AsyncDocument` save was in flight. A
call that does not have to wait does not trap, so the crash depends on timing. Sending the message
through the Objective-C runtime avoids the check:

```swift
let block: @convention(block) () -> Void = { /* … */ }
document.perform(#selector(NSDocument.performSynchronousFileAccess(_:)), with: block)
```

---

## 8. Swift: NSDocument's initializer and concurrent opening

The macOS 27.2 SDK marks `NSDocument` `NS_SWIFT_UI_ACTOR` and its reading and writing hooks
`NS_SWIFT_NONISOLATED` — but not `-init` (`NSDocument.h:98`), so Swift imports `init()` as
main-actor isolated, although concurrent opening calls it on a background thread (section 4.1).

**In the Swift 6 language mode, an `@objc` entry point of a main-actor-isolated synchronous member
asserts that it runs on the main thread.** `SILGenFunction::emitNativeToForeignThunk`
(`lib/SILGen/SILGenBridging.cpp`) calls `emitPreconditionCheckExpectedExecutor` for such members
when `isDynamicActorIsolationCheckingEnabled()` — the `DynamicActorIsolation` feature, on in the
Swift 6 mode (SE-0423). An override takes the overridden member's isolation by default
(`lib/Sema/TypeCheckConcurrency.cpp`, "Use the overridden decl's isolation as the default isolation
for this decl").

Measured by compiling consumer subclasses in the Swift 6 mode against a base compiled in the
Swift 5 mode, and reading the SILGen output for a call to `_checkExpectedExecutor` in each
`@objc … init()` thunk:

| Subclass | Its `init()` | Assertion in the `@objc` entry |
|---|---|---|
| of `NSDocument`, `override init() { super.init() }` | main actor | **yes** |
| of `NSDocument`, no initializer, `var text = ""` | synthesized, main actor | **yes** |
| of a base with `nonisolated override init()`, `nonisolated override init()` | nonisolated | no |
| same base, `override init()` without `nonisolated` | inherits nonisolated, no diagnostic | no |
| same base, no initializer, `var text = ""` | synthesized, nonisolated | no |
| same base, no initializer, `var items = NSMutableArray()` | synthesized, nonisolated | no |
| same base, no initializer, `let accessoryView = NSView()` | synthesized, nonisolated — `NSView()` evaluated without a diagnostic | no |

So a Swift 6 subclass of a plain `NSDocument` that has any stored property traps when it is opened
concurrently, and declaring `nonisolated init()` in the base is what removes the assertion from
every subclass shape. The last row is the hole left open: a default value that needs the main
thread compiles and runs off it.

The base's own `super.init()` call warns in the Swift 5 mode ("call to main actor-isolated
initializer 'init()' in a synchronous nonisolated context", group `ActorIsolatedCall`) — in that
mode it is an error downgraded to a warning. None of these silence it: `@preconcurrency import
AppKit`; `@preconcurrency` on the initializer; omitting the call (the implicit `super.init()` warns
at `<unknown>:0`); `@diagnose(ActorIsolatedCall, as: ignored)` (SE-0522, Swift 6.4), which by
design does not control errors.

Without the base's `nonisolated init()`, constructing the subclass from a detached task stops
compiling even in the Swift 5 mode ("main actor-isolated initializer 'init()' cannot be called from
outside of the actor") — the canary `AsyncDocumentTests` keeps.

---

## 9. SwiftUI's bridge: `URLPlatformDocument`

The macOS 27 SwiftUI `Document` protocol splits reading and writing the way `AsyncDocument` does:
`DocumentReader.read(from:progress:)` → `ReadableDocument.apply(snapshot:previous:)`,
`WritableDocument.snapshot(contentType:)` → `DocumentWriter.write(snapshot:to:previous:progress:)`.
On macOS it is wired into NSDocument by `URLPlatformDocument` → `PlatformDocument` → `NSDocument`,
created by `PlatformDocumentController`.

### 9.1 Static analysis

- **`-readFromURL:ofType:error:`** (`0x1B8F19BC8` → Swift body `0x1B8F18F2C`):
  `dispatch_semaphore_create(0)`; `box.didFinishReadingFromDisk = { semaphore.signal() }`;
  `swift_task_create` (flags `0x1C00`, no isolation); closure #2 (`0x1B8F19894`) awaits
  `box.read(from:ofType:)`; the calling thread waits on the semaphore, then throws if the error box
  is set. No main-thread branch. `read_swiftUI_v4` (`0x1B900D858`) first switches to
  `MainActor.shared`, then `readAndApplyDocument_v4` (`0x1B9005CA8`) runs the reader on the global
  executor, signals `didFinishReadingFromDisk` (`BLRAA` at `0x1B9006590`) and **only then** applies
  — so `readFromURL:` returns YES before `apply` has run, and an `apply` error lands in the error box
  after the read has already returned.
- **`-writeToURL:ofType:forSaveOperation:originalContentsURL:error:`** (`0x1B8F1A284` →
  `0x1B8F26540`): hard-links contents; semaphore; `box.didFinishWritingToDisk = signal`;
  `Task {}`; **`unblockUserInteraction` at once** (`0x1B8F26C00`); `semaphore.wait()`
  (`0x1B8F26C08`). The snapshot is taken afterwards, in `box.write` (`0x1B900F754`), after a hop to
  the ordinary `MainActor` — the main queue, not `continueAsynchronousWork…`. The error path of
  closure #2 (`0x1B8F1A048`) only logs and signals; the function saves `x21` to `var_98` on entry
  (`0x1B8F26564`) and restores it unchanged, so **a writer error never reaches NSDocument**.
- `canAsynchronouslyWriteToURL:…` (`0x1B8F18360`), `isEntireFileLoaded` (`0x1B8F18358`),
  `+autosavesInPlace` and `+canConcurrentlyReadDocumentsOfType:` (`0x1B8F18350`) all return YES
  unconditionally.
- Duplicating is overridden (`0x1B8F1A494` → `0x1B8F1B618`) to save with `NSSaveToOperation` to a
  unique autosave URL through the asynchronous path — AppKit's synchronous `duplicateAndReturnError:`
  (section 6) would hold the main thread on the semaphore while the writer waits for the main actor.

### 9.2 Measured with a `DocumentGroup` probe app (macOS 27.2)

| Scenario | Result |
|---|---|
| Introspection | `PlatformDocumentController`; `URLPlatformDocument -> PlatformDocument -> NSDocument`; `autosavesInPlace`, `canConcurrentlyReadDocuments`, `canAsynchronouslyWrite` all true |
| Open | `reader.read` finishes off the main thread, then `apply`, then the open's completion |
| `apply` throws | The open reports success and returns the document |
| Writer throws before writing | The save fails with a generic `NSCocoaErrorDomain` 512 ("could not be saved"); the writer's own error is lost; the document stays edited; the file is unchanged |
| Writer writes `PARTIAL`, then throws | **The save reports success**, `isDocumentEdited` becomes false, the file now reads `PARTIAL` |
| Revert from a menu action, and from main-actor code | No deadlock — the static prediction was wrong — but the order is: `reader.read` finishes, **`revertToContentsOfURL:` returns with the text still "in memory"**, then `apply` |
| Main thread waits for file access while `snapshot` is suspended (0.5 s) | **Deadlock.** The sample shows the main thread in `-[NSDocument performSynchronousFileAccessUsingBlock:]` → `-[_NSDocumentSerializationSemaphore wait]`, and the writer thread in `URLPlatformDocument.write(to:ofType:for:originalContentsURL:)` → `_dispatch_semaphore_wait_slow`. Whether an unsuspended `snapshot` can hit it was not measured |

`AsyncDocument` differs in exactly these places: the writer's error is returned to NSDocument, the
read returns only after `apply` has run on the main thread (section 1.1's channel when reading in
the background), and the snapshot is taken synchronously inside `canAsynchronouslyWrite`, before
the main thread is released.

---

## 10. The design comparison behind `AsyncDocument`

Two prototypes, one sample document, the same scenarios (macOS 27.2). "Hook" made NSDocument's own
hooks `async` and ran them on the main actor, spinning the run loop or parking the thread until they
finished; it is not in the repository. Where it waited for the main thread forever, the prototype
gave up after 5 s so the test could observe it.

| Scenario | Snapshot model (`AsyncDocument`) | Hook model |
|---|---|---|
| Save, then open on a background thread | Works | Works |
| An edit lands half way through writing | The file is the snapshot, consistent | First half old, second half new |
| A keystroke during a save, `autosavesInPlace == NO` | The main thread waits, as for a plain `NSDocument`; the keystroke stays unsaved | The keystroke is marked saved, the file is torn |
| The main thread waits for file access during a save | Finishes in ~0.1–0.2 s | Deadlock |
| Revert from a menu action | The main thread is held until the file is applied | Other main-thread work runs in the middle of the revert |
| Revert from Swift main-actor code | Works | Never reaches the hook: GCD does not start another main-queue block while one is running, and a `@MainActor` job is one |
| Read and write errors | Reach the caller | Reach the caller |
