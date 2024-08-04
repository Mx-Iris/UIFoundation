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

    @IBOutlet var customView: View!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        customView.borderLocation = .center
        customView.borderPositions = [.left, .bottom]
        customView.borderWidth = 2
        customView.borderColor = .red
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
