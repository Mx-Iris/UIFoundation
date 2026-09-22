//
//  GettingStartedView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/5/25).
//

import AppKit
import UIFoundationComponent

@available(macOS 14.0, *)
final class GettingStartedView: ChapterView {
    override func updateProperties() {
        super.updateProperties()
        componentEngine.component = VStack(spacing: 40) {
            Text("Getting Started", font: .title)

            VStack(spacing: 10) {
                Text("Welcome to the component layout example", font: .subtitle)
                Text("These chapters walk through UIFoundationComponent -- a declarative layout system that computes frames itself instead of going through Auto Layout, and pairs that with view reuse and visible-frame culling.", font: .body)
                    .textColor(.secondaryLabel)
            }

            VStack(spacing: 10) {
                Text("How to use this", font: .subtitle)
                VStack(spacing: 10) {
                    Text("• Use the sidebar on the left to move between chapters", font: .body).textColor(.secondaryLabel)
                    Text("• Every sample below shows its own source, captured at compile time by the #CodeExample macro -- so the code you read is the code that ran", font: .body).textColor(.secondaryLabel)
                    Text("• Samples are live: resize the window and watch them re-lay out", font: .body).textColor(.secondaryLabel)
                }
            }

            VStack(spacing: 15) {
                Text("What is different on AppKit", font: .subtitle)
                VStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("The library ships the layout system, not the widgets", font: .bodyBold)
                        Text("Text, Image and Separator are defined by this example, not by UIFoundationComponent. Writing your own leaf components is the expected path, and the Text in this example is the worked demonstration of it.", font: .body)
                            .textColor(.secondaryLabel)
                    }
                    VStack(spacing: 4) {
                        Text("Hosts must be flipped", font: .bodyBold)
                        Text("The layout system places children from the top-left downwards. NSView draws from the bottom-left, so a host is either flipped itself or the engine inserts a flipped container for it.", font: .body)
                            .textColor(.secondaryLabel)
                    }
                    VStack(spacing: 4) {
                        Text("Redraws come from Observation", font: .bodyBold)
                        Text("Each chapter rebuilds its component tree in updateProperties(). Reading an @Observable model there is enough -- changing it re-drives the method with nothing to call by hand.", font: .body)
                            .textColor(.secondaryLabel)
                    }
                }
            }

            VStack(spacing: 10) {
                Text("Ready?", font: .subtitle)
                Text("Pick a chapter from the sidebar.", font: .body).textColor(.secondaryLabel)
            }
        }
        .inset(24)
        .ignoreHeightConstraint()
        .scrollView()
        .fill()
    }
}
