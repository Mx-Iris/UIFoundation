//
//  Collection+TabsControl.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import Foundation

extension Collection {
    /// Returns the element at `index` if it is within bounds, otherwise `nil`.
    subscript(safe index: Index) -> Element? {
        return index < endIndex ? self[index] : nil
    }
}

#endif
