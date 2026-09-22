//
//  PlacementExamplesView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao,
//  2025). Converted for AppKit: chapter base class, NS-prefixed types,
//  and the UIKit-only modifiers dropped.
//

import AppKit
import UIFoundationComponent

@available(macOS 14.0, *)
final class PlacementExamplesView: ChapterView {
    override func updateProperties() {
        super.updateProperties()
        componentEngine.component = VStack(spacing: 40) {
            Text("Placement Modifiers", font: .title)
            
            // Inset Examples
            VStack(spacing: 10) {
                Text("Inset modifiers", font: .subtitle)
                Text("Inset adds padding around a component. It's the fundamental spacing modifier.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 10) {
                    Text("Uniform inset", font: .caption)
                    #CodeExampleNoInsets(
                        Text("Uniform padding", font: .body)
                            .backgroundColor(.systemBlue)
                            .inset(20)
                    )
                    
                    Text("Horizontal and vertical inset", font: .caption)
                    #CodeExampleNoInsets(
                        Text("H: 30, V: 10", font: .body)
                            .backgroundColor(.systemGreen)
                            .inset(h: 30, v: 10)
                    )
                    
                    Text("Individual edge inset", font: .caption)
                    #CodeExampleNoInsets(
                        Text("Top: 20, Rest: 8", font: .body)
                            .backgroundColor(.systemOrange)
                            .inset(top: 30, rest: 8)
                    )
                }
            }
            
            // Offset Examples
            VStack(spacing: 10) {
                Text("Offset modifiers", font: .subtitle)
                Text("Offset moves a component from its original position without affecting layout.", font: .body).textColor(.secondaryLabel)

                #CodeExample(
                    ZStack {
                        Space(width: 20, height: 20).backgroundColor(.systemGray5)
                        Space(width: 20, height: 20).backgroundColor(.systemBlue)
                            .offset(x: 10, y: -10)
                    }
                )
            }
            
            // Overlay Examples
            VStack(spacing: 10) {
                Text("Overlay modifiers", font: .subtitle)
                Text("Overlay places content on top of another component. Simpler than using ZStack. The size of the overlay will match the background component.", font: .body).textColor(.secondaryLabel)

                VStack(spacing: 10) {
                    Text("Simple overlay", font: .caption)
                    #CodeExampleNoInsets(
                        Text("Base content", font: .title)
                            .inset(40)
                            .backgroundColor(.systemGray5)
                            .overlay {
                                Text("Overlay", font: .body)
                                    .textColor(.white)
                                    .backgroundColor(.systemBlue.withAlphaComponent(0.5))
                            }
                    )
                    
                    Text("Loading overlay (from ZStack example)", font: .caption)
                    #CodeExampleNoInsets(
                        VStack(spacing: 10) {
                            Text("Content", font: .title)
                            Text("This content is loading", font: .body)
                        }
                        .inset(30)
                        .overlay {
                            VStack(spacing: 10, justifyContent: .center, alignItems: .center) {
                                Image(systemName: "arrow.clockwise").tintColor(.white)
                                Text("Loading...", font: .body).textColor(.white)
                            }
                            .backgroundColor(.black.withAlphaComponent(0.7))
                        }
                    )
                }
            }
            
            // Background Examples
            VStack(spacing: 10) {
                Text("Background modifiers", font: .subtitle)
                Text("Background places content behind another component. Simpler than using ZStack. The size of the background will match the foreground component.", font: .body).textColor(.secondaryLabel)

                VStack(spacing: 10) {
                    Text("Simple background", font: .caption)
                    #CodeExampleNoInsets(
                        Text("Foreground", font: .body)
                            .inset(20)
                            .background {
                                Text("Background", font: .title).backgroundColor(.systemBlue)
                            }
                    )
                    
                    Text("Gradient background", font: .caption)
                    #CodeExampleNoInsets(
                        Text("Gradient Text", font: .title)
                            .textColor(.white)
                            .inset(30)
                            .background {
                                ViewComponent<GradientView>().colors([.systemPink, .systemPurple])
                                    .cornerRadius(15)
                            }
                    )
                }
            }
            
            // Badge Examples
            VStack(spacing: 10) {
                Text("Badge modifiers", font: .subtitle)
                Text("Badge positions a small overlay relative to content. ", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 10) {
                    Text("Notification badge (from ZStack example)", font: .caption)
                    #CodeExample(
                        Image(systemName: "bell.fill", withConfiguration: NSImage.SymbolConfiguration(pointSize: 40, weight: .regular))
                            .tintColor(.label)
                            .badge {
                                Text("3", font: .caption)
                                    .textColor(.white)
                                    .inset(h: 6, v: 2)
                                    .backgroundColor(.systemRed)
                                    .cornerRadius(8)
                            }
                    )
                    
                    Text("Badge positions", font: .caption)
                    #CodeExample(
                        HStack(spacing: 20) {
                            // Top-right (default)
                            Space(width: 50, height: 50)
                                .backgroundColor(.systemBlue)
                                .badge {
                                    Circle(size: 12).backgroundColor(.systemRed)
                                }
                            
                            // Bottom-right
                            Space(width: 50, height: 50)
                                .backgroundColor(.systemGreen)
                                .badge(verticalAlignment: .end) {
                                    Circle(size: 12).backgroundColor(.systemRed)
                                }
                            
                            // Top-left
                            Space(width: 50, height: 50)
                                .backgroundColor(.systemOrange)
                                .badge(horizontalAlignment: .start) {
                                    Circle(size: 12).backgroundColor(.systemRed)
                                }
                        }
                    )
                    
                    Text("Badge with offset", font: .caption)
                    #CodeExample(
                        Image(systemName: "person.circle.fill")
                            .contentMode(.scaleAspectFit)
                            .size(width: 50, height: 50)
                            .tintColor(.systemIndigo)
                            .badge(offset: CGPoint(x: 5, y: -5)) {
                                Image(systemName: "checkmark.circle.fill")
                                    .tintColor(.systemGreen)
                            }
                    )
                }
            }
            
            // Centered Examples
            VStack(spacing: 10) {
                Text("Centered modifier", font: .subtitle)
                Text("Centers content within available space. Uses ZStack with .fill() internally.", font: .body).textColor(.secondaryLabel)
                #CodeExampleNoInsets(
                    Text("Centered", font: .body)
                        .backgroundColor(.systemBlue)
                        .inset(20)
                        .centered()
                        .size(width: 200, height: 200)
                        .backgroundColor(.systemGray6)
                )
            }
            
        }.inset(24).ignoreHeightConstraint().scrollView().fill()
    }
}

// Helper gradient view for background example
@available(macOS 14.0, *)
final class GradientView: NSView {
    // `UIView.layerClass` has no AppKit counterpart -- AppKit asks the view to
    // build its own backing layer instead, and only if it wants one at all.
    // Hence both halves: the factory, and `wantsLayer`, which UIKit views never
    // need because they are always layer-backed.
    override func makeBackingLayer() -> CALayer {
        CAGradientLayer()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var colors: [NSColor] = [] {
        didSet {
            updateColors()
        }
    }

    func updateColors() {
        (layer as? CAGradientLayer)?.colors = colors.map { $0.cgColor }
    }
}

@available(macOS 14.0, *)
struct Circle: ComponentBuilder {
    let size: CGFloat
    
    func build() -> some Component {
        Space(width: size, height: size)
            .roundedCorner()
    }
}
