//
//  Imports.swift
//
//
//  Created by Suyash Srijan on 28/06/2021.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

public typealias InvalidatingViewType = NSView

public typealias InvalidatingViewProtocol = NSViewInvalidatingType

public protocol NSViewInvalidatingType {
    func invalidate(view: InvalidatingViewType)
}
#endif

#if canImport(UIKit)
import UIKit

public typealias InvalidatingViewType = UIView

public typealias InvalidatingViewProtocol = UIViewInvalidatingType

public protocol UIViewInvalidatingType {
    func invalidate(view: InvalidatingViewType)
}
#endif
