//
//  Invalidations.swift
//
//
//  Created by Suyash Srijan on 28/06/2021.
//

import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public enum Invalidations {
    public struct Layout: InvalidatingViewProtocol {
        public static let layout: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            view.needsLayout = true
            #endif

            #if canImport(UIKit)
            view.setNeedsLayout()
            #endif
        }
    }

    public struct Display: InvalidatingViewProtocol {
        public static let display: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            view.setNeedsDisplay(view.bounds)
            #endif

            #if canImport(UIKit)
            view.setNeedsDisplay()
            #endif
        }
    }

    public struct Constraints: InvalidatingViewProtocol {
        public static let constraints: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            view.needsUpdateConstraints = true
            #endif

            #if canImport(UIKit)
            view.setNeedsUpdateConstraints()
            #endif
        }
    }

    public struct IntrinsicContentSize: InvalidatingViewProtocol {
        public static let intrinsicContentSize: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            view.invalidateIntrinsicContentSize()
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public struct RestorableState: InvalidatingViewProtocol {
        public static let restorableState: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            view.invalidateRestorableState()
        }
    }
    #endif

    #if canImport(UIKit)
    public struct Configuration: InvalidatingViewProtocol {
        public static let configuration: Self = .init()

        public func invalidate(view: InvalidatingViewType) {
            if #available(iOS 14, *) {
                switch view {
                case let view as UITableViewCell:
                    view.setNeedsUpdateConfiguration()
                case let view as UICollectionViewCell:
                    view.setNeedsUpdateConfiguration()
                case let view as UITableViewHeaderFooterView:
                    view.setNeedsUpdateConfiguration()
                default:
                    assertionFailure("View '\(String(describing: view))' does not support configuration updates!")
                }
            }
        }
    }
    #endif
}
