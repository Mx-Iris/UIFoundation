//
//  NSImage+TabsControl.swift
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

extension NSImage {
    func imageWithTint(_ tint: NSColor) -> NSImage {
        var imageRect = NSRect.zero
        imageRect.size = self.size

        let highlightImage = NSImage(size: imageRect.size)

        highlightImage.lockFocus()

        self.draw(in: imageRect, from: NSRect.zero, operation: .sourceOver, fraction: 1.0)

        tint.set()
        imageRect.fill(using: .sourceAtop)

        highlightImage.unlockFocus()

        return highlightImage
    }
}

#endif
