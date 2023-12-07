//
//  MainWindowController.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import AppKit
import UIFoundation

class MainWindowController: NSWindowController, StoryboardWindowController {
    static var storyboard: NSStoryboard { .main }
    static var storyboardIdentifier: String { .init(describing: self) }
}
