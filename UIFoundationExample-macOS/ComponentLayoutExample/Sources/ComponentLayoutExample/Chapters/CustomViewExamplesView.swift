//
//  CustomViewExamplesView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao,
//  2025). Converted for AppKit: chapter base class, NS-prefixed types,
//  and the UIKit-only modifiers dropped.
//

import AppKit
import UIFoundationComponent

@available(macOS 14.0, *)
@GenerateCode
final class MyCustomView: NSView {
    var name: String = ""
}

@available(macOS 14.0, *)
final class CustomViewExamplesView: ChapterView {
    override func updateProperties() {
        super.updateProperties()
        componentEngine.component = VStack {
            Text("Custom View", font: .title)
            ViewComponent<MyCustomView>().size(width: 200, height: 50)
            Code(MyCustomView.codeRepresentation)
        }.inset(24).ignoreHeightConstraint().scrollView().fill()
    }
}
