//
//  ViewController.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import Cocoa
import UIFoundation

class MainStoryboardViewController: NSViewController, StoryboardViewController {
    class var storyboard: NSUIStoryboard { .main }

    class var storyboardIdentifier: String { .init(describing: Self.self) }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
