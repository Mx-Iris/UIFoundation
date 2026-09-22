//
//  Slider.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/5/25), rewritten for `NSSlider`.
//
//  The chapters use this to drive a live parameter -- spacing, column count,
//  a constraint -- and watch the layout respond.
//

import AppKit
import UIFoundationComponent

/// A slider wrapped as a component host, so a chapter can drop it into a stack.
final class Slider: ComponentView {
    let slider = NSSlider()

    var onValueChanged: ((CGFloat) -> Void)?

    var minimumValue: CGFloat {
        get { slider.minValue }
        set { slider.minValue = newValue }
    }

    var maximumValue: CGFloat {
        get { slider.maxValue }
        set { slider.maxValue = newValue }
    }

    var value: CGFloat = 0 {
        didSet {
            // Upstream guards on `UISlider.isTracking`, which AppKit's
            // `NSSlider` has no counterpart to. The flag below serves the same
            // purpose: it stops the value the slider just reported from being
            // written straight back into the knob mid-drag, which reads as the
            // knob fighting the pointer.
            guard !isReportingValue else { return }
            slider.doubleValue = value
        }
    }

    private var isReportingValue = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        slider.target = self
        slider.action = #selector(valueChanged)
        componentEngine.component = slider.fill()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func valueChanged() {
        isReportingValue = true
        value = slider.doubleValue
        isReportingValue = false
        onValueChanged?(value)
    }
}
