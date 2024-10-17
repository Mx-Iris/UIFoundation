#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@objc
public protocol NSTableViewInternalDataSource: NSTableViewDataSource {
    @objc(_tableView:viewForTableColumn:row:)
    func _tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    @objc(_tableView:rowViewForRow:)
    func _tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
    @objc(_tableView:isGroupRow:)
    func _tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool
}

#endif
