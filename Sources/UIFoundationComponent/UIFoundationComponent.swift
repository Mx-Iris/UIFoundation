//
//  UIFoundationComponent.swift
//  UIFoundation
//
//  Umbrella imports for the component layout system.
//
//  The sources in this target are ported from lkzhao/UIComponent, which reaches
//  UIKit through a single `@_exported import` rather than importing it per file.
//  Keeping that shape here means the ported files need no import boilerplate,
//  and it re-exports `UIFoundationTypealias` so callers writing components get
//  `NSUIView` and friends without a second import.
//

@_exported import Foundation
@_exported import CoreGraphics
@_exported import QuartzCore
@_exported import UIFoundationTypealias
// The platform-bridging shims this target renders through -- `box.setFrame(_:)`,
// `box.viewportBounds`, `box.backingLayer` and the rest -- live in the toolbox.
@_exported import UIFoundationToolbox

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@_exported import AppKit
#endif

#if canImport(UIKit)
@_exported import UIKit
#endif
