//
//  TabsControlDelegateInterceptor.swift
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

final class TabsControlDelegateInterceptor: NSObject {
    weak var receiver: NSObject?

    override func forwardingTarget(for aSelector: Selector) -> Any? {
        if self.receiver?.responds(to: aSelector) == true { return self.receiver }
        return super.forwardingTarget(for: aSelector)
    }

    override func responds(to aSelector: Selector) -> Bool {
        if self.receiver?.responds(to: aSelector) == true { return true }
        return super.responds(to: aSelector)
    }
}

#endif
