//
//  ViewHierarchy.swift
//  CodeOrganizerUI
//
//  Created by JH on 2023/7/12.
//

import UIFoundationTypealias

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit) && !os(watchOS)
import UIKit
#else
#error("Unsupported platform")
#endif

#if !os(watchOS)
public protocol ViewHierarchyComponent {
    func attach(to view: NSUIView)
    func attach(to viewController: NSUIViewController)
}

@resultBuilder
public enum ViewHierarchyBuilder {
    public static func buildBlock() -> [ViewHierarchyComponent] {
        []
    }

    public static func buildBlock(_ components: [ViewHierarchyComponent]...) -> [ViewHierarchyComponent] {
        components.flatMap { $0 }
    }

    public static func buildEither(first component: [ViewHierarchyComponent]?) -> [ViewHierarchyComponent] {
        component ?? []
    }

    public static func buildEither(second component: [ViewHierarchyComponent]?) -> [ViewHierarchyComponent] {
        component ?? []
    }

    public static func buildOptional(_ component: [ViewHierarchyComponent]?) -> [ViewHierarchyComponent] {
        component ?? []
    }

    public static func buildExpression(_ expression: [ViewHierarchyComponent]?) -> [ViewHierarchyComponent] {
        expression ?? []
    }

    public static func buildExpression(_ expression: ViewHierarchyComponent?) -> [ViewHierarchyComponent] {
        expression.map { [$0] } ?? []
    }

    public static func buildArray(_ components: [[ViewHierarchyComponent]]) -> [ViewHierarchyComponent] {
        components.flatMap { $0 }
    }
}

@dynamicMemberLookup
public struct ViewItem<View: NSUIView>: ViewHierarchyComponent {
    private let view: View

    @discardableResult
    public init(_ view: View) {
        self.view = view
    }

    @discardableResult
    public init(_ view: View, @ViewHierarchyBuilder builder: () -> [ViewHierarchyComponent]) {
        self.view = view
        builder().forEach { $0.attach(to: view) }
    }

    public func attach(to view: NSUIView) {
        view.addSubview(self.view)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addSubview(self.view)
    }

    public subscript<Member>(dynamicMember keyPath: ReferenceWritableKeyPath<View, Member>) -> Member {
        set {
            view[keyPath: keyPath] = newValue
        }
        get {
            view[keyPath: keyPath]
        }
    }

    public subscript<Member>(dynamicMember keyPath: ReferenceWritableKeyPath<View, Member>) -> (Member) -> Self {
        return { newMember in
            view[keyPath: keyPath] = newMember
            return self
        }
    }
}

public struct LayoutGuideItem: ViewHierarchyComponent {
    private let layoutGuide: NSUILayoutGuide

    public init(_ layoutGuide: NSUILayoutGuide) {
        self.layoutGuide = layoutGuide
    }

    public func attach(to view: NSUIView) {
        view.addLayoutGuide(layoutGuide)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addLayoutGuide(layoutGuide)
    }
}

@dynamicMemberLookup
public struct ControllerItem<ViewController: NSUIViewController>: ViewHierarchyComponent {
    private let controller: ViewController

    @discardableResult
    public init(_ controller: ViewController) {
        self.controller = controller
    }

    @discardableResult
    public init(_ controller: ViewController, @ViewHierarchyBuilder builder: () -> [ViewHierarchyComponent]) {
        self.controller = controller
        builder().forEach { $0.attach(to: controller.view) }
    }

    public func attach(to view: NSUIView) {
        view.addSubview(controller.view)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addSubview(controller.view)
        viewController.addChild(controller)
    }

    public subscript<Member>(dynamicMember keyPath: ReferenceWritableKeyPath<ViewController, Member>) -> Member {
        set {
            controller[keyPath: keyPath] = newValue
        }
        get {
            controller[keyPath: keyPath]
        }
    }

    public subscript<Member>(dynamicMember keyPath: ReferenceWritableKeyPath<ViewController, Member>) -> (Member) -> Self {
        return { newMember in
            controller[keyPath: keyPath] = newMember
            return self
        }
    }
}

extension NSUILayoutGuide: ViewHierarchyComponent {
    public func attach(to view: NSUIView) {
        view.addLayoutGuide(self)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addLayoutGuide(self)
    }
}

extension NSUIView: ViewHierarchyComponent {
    public func attach(to view: NSUIView) {
        view.addSubview(self)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addSubview(self)
    }

    @discardableResult
    public func hierarchy(@ViewHierarchyBuilder _ builder: () -> [ViewHierarchyComponent]) -> Self {
        builder().forEach { $0.attach(to: self) }
        return self
    }
}

extension NSUIViewController: ViewHierarchyComponent {
    public func attach(to view: NSUIView) {
        view.addSubview(self.view)
    }

    public func attach(to viewController: NSUIViewController) {
        viewController.view.addSubview(view)
        viewController.addChild(self)
    }

    @discardableResult
    public func hierarchy(@ViewHierarchyBuilder _ builder: () -> [ViewHierarchyComponent]) -> Self {
        builder().forEach { $0.attach(to: self) }
        return self
    }
}

// protocol ViewHierarchyBuildable {
//    var __buildRootView: CocoaView { get }
// }
//
// extension CocoaViewController: ViewHierarchyBuildable {
//    var __buildRootView: CocoaView { view }
// }
//
// extension CocoaView: ViewHierarchyBuildable {
//    var __buildRootView: CocoaView { self }
// }
//
// extension ViewHierarchyBuildable {
//    public func build(@ViewHierarchyBuilder builder: () -> [ViewHierarchyComponent]) {
//        builder().forEach { $0.attach(to: __buildRootView) }
//    }
// }
#endif
