//
//  BorderLabel.swift
//  CodeOrganizerUI
//
//  Created by JH on 2023/10/13.
//

import AppKit

open class RoundedBorderLabel: Label {
    
    @Invalidating(.display)
    open var borderColor: NSColor = .clear {
        didSet {
            layer?.borderColor = borderColor.cgColor
        }
    }

    @Invalidating(.display)
    open var borderWidth: CGFloat = 0 {
        didSet {
            layer?.borderWidth = borderWidth
        }
    }

    @Invalidating(.display)
    open var layerBackgroundColor: NSColor = .clear {
        didSet {
            layer?.backgroundColor = layerBackgroundColor.cgColor
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    open override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
    }
}
