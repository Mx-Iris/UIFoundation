//
//  NSButton+TabsControl.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

extension NSButton {
    static func auxiliaryButton(withImageNamed imageName: String, target: AnyObject?, action: Selector?) -> NSButton {
        let button = NSButton()

        button.target = target
        button.action = action
        button.isEnabled = (target != nil && action != nil)
        button.isContinuous = true
        button.imagePosition = .imageOnly
        if let url = Bundle.module.url(forResource: imageName, withExtension: "pdf", subdirectory: "Templates") {
            button.image = NSImage(contentsOf: url)
        }
        if let image = button.image {
            var rect = CGRect.zero
            rect.size = image.size
            rect.size.width += 4.0
            button.frame = rect
        }

        return button
    }
}

#endif
