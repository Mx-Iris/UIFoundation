//
//  MainSplitViewController.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import AppKit
import UIFoundation

class MainSplitViewController: NSSplitViewController, StoryboardViewController {
    static var storyboard: NSUIStoryboard { .main }
    static var storyboardIdentifier: String { .init(describing: self) }
}


extension NSStoryboard {
    static let main = NSStoryboard(name: "Main", bundle: .main)
}
