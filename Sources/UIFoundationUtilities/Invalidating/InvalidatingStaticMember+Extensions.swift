//
//  InvalidatingStaticMember+Extensions.swift
//
//
//  Created by Suyash Srijan on 28/06/2021.
//

import Foundation

extension InvalidatingViewProtocol where Self == Invalidations.Layout {
    public static var layout: Self { .layout }
}

extension InvalidatingViewProtocol where Self == Invalidations.Display {
    public static var display: Self { .display }
}

extension InvalidatingViewProtocol where Self == Invalidations.Constraints {
    public static var constraints: Self { .constraints }
}

extension InvalidatingViewProtocol where Self == Invalidations.IntrinsicContentSize {
    public static var intrinsicContentSize: Self { .intrinsicContentSize }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension InvalidatingViewProtocol where Self == Invalidations.RestorableState {
    public static var restorableState: Self { .restorableState }
}
#endif

#if canImport(UIKit)
import UIKit

extension InvalidatingViewProtocol where Self == Invalidations.Configuration {
    public static var configuration: Self { .configuration }
}
#endif
