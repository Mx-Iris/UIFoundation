#if canImport(AppKit) && !targetEnvironment(macCatalyst)

// `WindowedTableViewDataSource` is built around `UIFoundationWindowedRows`'
// `WindowedRowsController`, `WindowedRowSource` and `WindowedDisplayedRows`;
// re-exported so that `import UIFoundation` is all a host needs to use it.
@_exported import UIFoundationWindowedRows

#endif
