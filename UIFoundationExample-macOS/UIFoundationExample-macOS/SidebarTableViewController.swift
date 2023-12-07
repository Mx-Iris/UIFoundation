//
//  SidebarTableViewController.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import AppKit
import UIFoundation

enum Module: String, CaseIterable {
    case indicators = "Indicators"
    
    
}


class SidebarTableViewController: TableViewController {
    
    var dataSource: [Module] = Module.allCases
    
    override func viewDidLoad() {
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = tableView.box.makeView(withType: <#T##CellView.Type#>, onwer: <#T##Any?#>)
    }
    
}
