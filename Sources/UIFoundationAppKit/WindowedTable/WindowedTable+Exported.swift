#if canImport(AppKit) && !targetEnvironment(macCatalyst)

// `WindowedTableViewDataSource` is built around FrameworkToolbox's
// `WindowedRowsController`, `WindowedRowSource` and `WindowedDisplayedRows`;
// re-exported so that `import UIFoundation` is all a host needs to use it.
@_exported import WindowedRowsToolbox

#endif
