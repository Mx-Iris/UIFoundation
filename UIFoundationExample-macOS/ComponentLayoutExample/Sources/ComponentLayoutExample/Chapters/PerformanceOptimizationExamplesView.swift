//
//  PerformanceOptimizationExamplesView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao,
//  2025). Converted for AppKit: chapter base class, NS-prefixed types,
//  and the UIKit-only modifiers dropped.
//

import AppKit
import UIFoundationComponent

@available(macOS 14.0, *)
final class PerformanceOptimizationExamplesView: ChapterView {
    @Observable
    class PerformanceViewModel {
        var showLazyExample: Bool = false
        var itemCount: Int = 1000
        var useReuse: Bool = false
        var useLazy: Bool = false
    }
    
    let viewModel = PerformanceViewModel()
    
    override func updateProperties() {
        super.updateProperties()
        let viewModel = viewModel
        componentEngine.component = VStack(spacing: 40) {
            Text("Performance Optimization", font: .title)
            
            VStack(spacing: 10) {
                Text("Overview", font: .subtitle)
                Text("UIFoundationComponent provides excellent performance out of the box. It intelligently renders only what's visible, defers view creation until needed, and efficiently manages resources. However, for demanding scenarios like large lists or complex layouts, you can further optimize performance using the techniques below.", font: .body).textColor(.secondaryLabel)
                VStack(spacing: 8) {
                    HStack(spacing: 8, alignItems: .center) {
                        Image(systemName: "eye")
                            .tintColor(.systemBlue)
                            .contentMode(.center)
                            .size(width: 24, height: 24)
                        Text("Renders only visible views automatically", font: .body)
                    }
                    HStack(spacing: 8, alignItems: .center) {
                        Image(systemName: "clock")
                            .tintColor(.systemGreen)
                            .contentMode(.center)
                            .size(width: 24, height: 24)
                        Text("Defers view creation until scroll", font: .body)
                    }
                    HStack(spacing: 8, alignItems: .center) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .tintColor(.systemOrange)
                            .contentMode(.center)
                            .size(width: 24, height: 24)
                        Text("Optional view reuse for efficiency", font: .body)
                    }
                    HStack(spacing: 8, alignItems: .center) {
                        Image(systemName: "bolt.fill")
                            .tintColor(.systemPurple)
                            .contentMode(.center)
                            .size(width: 24, height: 24)
                        Text("Lazy layout for complex components", font: .body)
                    }
                }.inset(h: 16, v: 10).backgroundColor(.systemGray6).cornerRadius(12)
            }
            
            // MARK: - Automatic Optimizations
            
            VStack(spacing: 10) {
                Text("Built-in optimizations", font: .subtitle)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("1. Visible-only rendering", font: .bodyBold)
                        Text("UIFoundationComponent only renders views that are visible in the current viewport. When you scroll, views are created on-demand and removed when scrolled off-screen. This means you can have thousands of items in a list with minimal memory footprint.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            VStack {
                                for i in 0...10000 {
                                    Text("Item \\(i)").inset(10)
                                }
                            }
                            .scrollView()
                            
                            // Only visible items are created as NSViews
                            // Others exist only as layout information
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("2. Deferred view creation", font: .bodyBold)
                        Text("Views are not created during layout. UIFoundationComponent first calculates layout for all components, then creates NSView instances only for visible items when rendering. This separates expensive layout calculations from view creation.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // Layout phase: Fast, calculates size and position
                            // No NSViews created yet
                            
                            // Render phase: Creates NSViews only for visible items
                            // Happens when scrolling or initial display
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("3. Automatic visibility testing", font: .bodyBold)
                        Text("The ComponentEngine performs visibility tests to determine which components intersect with the visible frame. Different layout types (VStack, Flow, Waterfall) have optimized visibility algorithms that avoid checking every single item.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // UIFoundationComponent checks: Does this component intersect
                            // with the visible viewport?
                            
                            // VStack: Binary search for visible items
                            // Flow: Row-based visibility testing
                            // Each layout optimizes for its structure
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("4. Component creation is cheap", font: .bodyBold)
                        Text("Components are Swift value types (structs), making them incredibly lightweight to create. You can freely create component hierarchies multiple times without performance concerns. Layout calculations and view rendering are batched and optimized, so even if you rebuild the entire component tree on every state change, it remains performant.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // Creating components is cheap - they're just structs
                            let component = VStack {
                                Text("Hello")
                                Text("World")
                            }  // No NSViews created, just data structures
                            
                            // Even rebuilding the tree on each update is fine
                            func render() {
                                componentEngine.component = VStack {
                                    for item in items {
                                        Text(item)  // Recreated each time, still fast
                                    }
                                }
                            }
                            """
                        }
                    }
                }
                .inset(16)
                .backgroundColor(.systemBlue.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - How Component Creation Works
            
            VStack(spacing: 10) {
                Text("How component creation stays fast", font: .subtitle)
                Text("Understanding how UIFoundationComponent batches work helps you write efficient code without overthinking performance.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("Components are just data", font: .bodyBold)
                        Text("When you create a VStack, HStack, or Text component, you're just creating a lightweight Swift struct. No layout calculations happen, no views are created. It's similar to creating a simple data structure.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // This is cheap - just creating structs
                            let header = HStack {
                                Text("Title")
                                Image(systemName: "star")
                            }
                            
                            // This is also cheap - structs containing structs
                            let page = VStack {
                                header
                                Text("Content")
                            }
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("Layout and rendering are batched", font: .bodyBold)
                        Text("When you assign a component to componentEngine.component, UIFoundationComponent doesn't immediately calculate layout or render views. Instead, it marks the engine as needing update and schedules a batch update. Multiple changes in the same run loop are coalesced into a single layout pass.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // All these assignments are batched into one update
                            viewModel.item1 = "Updated"  // Triggers component rebuild
                            viewModel.item2 = "Updated"  // Triggers component rebuild
                            viewModel.item3 = "Updated"  // Triggers component rebuild
                            
                            // Only one layout pass happens after all changes complete
                            // Layout: Calculate positions of all components
                            // Render: Update/create only changed views
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("Even better: Use updateProperties for automatic batching", font: .bodyBold)
                        Text("The updateProperties() method provides an even more efficient pattern. When you use @Observable view models, UIFoundationComponent automatically batches all state changes and calls updateProperties once, where you rebuild the component tree. This means component tree creation is also batched with the layout and render phases.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            @Observable
                            class ViewModel {
                                var count = 0
                                var isEnabled = false
                            }
                            
                            override func updateProperties() {
                                super.updateProperties()
                                componentEngine.component = VStack {
                                    Text("Count: \\(viewModel.count)")
                                    if viewModel.isEnabled {
                                        Text("Enabled")
                                    }
                                }
                            }
                            
                            // Multiple state changes trigger ONE updateProperties call
                            viewModel.count += 1
                            viewModel.isEnabled = true
                            // → Single updateProperties() → Single layout → Single render
                            """
                        }
                        
                        ChapterLink(
                            title: "See State Management chapter for more details on @Observable and updateProperties",
                            chapterIdentifier: "state-management",
                            anchorId: "observable-pattern"
                        )
                    }
                }
                .inset(16)
                .backgroundColor(.systemMint.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - ViewComponent vs Manual Views
            
            VStack(spacing: 10) {
                Text("Prefer ViewComponent over manual NSViews", font: .subtitle)
                Text("When you need to use UIKit views, always use ViewComponent with a generator function rather than creating NSView instances directly. This allows UIFoundationComponent to defer view creation until the component is actually visible.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("❌ Avoid: Creating views eagerly", font: .bodyBold).textColor(.systemRed)
                        Text("This creates all UISwitch instances immediately during component construction, even for items not visible on screen.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // BAD: Creates 1000 UISwitch instances immediately
                            VStack {
                                for i in 0...1000 {
                                    let toggle = UISwitch()  // Created right away!
                                    toggle.isOn = false
                                    ViewComponent(view: toggle)
                                }
                            }
                            .scrollView()
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("✅ Prefer: Using ViewComponent generator", font: .bodyBold).textColor(.systemGreen)
                        Text("The generator function is called only when the view becomes visible. UIFoundationComponent creates views lazily as you scroll, keeping memory usage low.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            // GOOD: Views created only when scrolled into view
                            VStack {
                                for i in 0...1000 {
                                    ViewComponent<UISwitch>()  // Generator approach
                                        .isOn(false)
                                        .size(width: 62, height: 30)
                                }
                            }
                            .scrollView()
                            """
                        }
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("💡 Best: Custom NSView with updateProperties", font: .bodyBold).textColor(.systemBlue)
                        Text("For complex cells, create a custom NSView subclass. This allows internal layout and state management to be encapsulated within the view and only gets run when the view is visible.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            class ItemCell: NSView {
                                var item: Item? {
                                    didSet {
                                        guard item != oldValue else { return }
                                        componentEngine.component = VStack {
                                            Text(item?.title ?? "")
                                            Text(item?.subtitle ?? "")
                                        }.inset(10)
                                    }
                                }
                            }
                            
                            VStack {
                                for item in items {
                                    ViewComponent<ItemCell>()
                                        .item(item)
                                        .size(width: .fill, height: 60)
                                }
                            }
                            .scrollView()
                            """
                        }
                    }
                }
                .inset(16)
                .backgroundColor(.systemTeal.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - View Reuse
            
            VStack(spacing: 10) {
                Text("View reuse with reuseKey", font: .subtitle)
                Text("In version 5.0+, view reuse is opt-in using the .reuseKey() modifier. When you assign a reuse key, UIFoundationComponent pools and reuses views of that type instead of destroying and recreating them. This can improve performance for expensive view initialization, but requires careful state management.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("When to use view reuse", font: .bodyBold)
                        Text("Consider using view reuse when:", font: .body).textColor(.secondaryLabel)
                        VStack(spacing: 4) {
                            Text("• View initialization is expensive (complex setup, heavy graphics)", font: .body)
                            Text("• You have many similar items in a scrollable list", font: .body)
                            Text("• You can properly manage view state during reuse", font: .body)
                        }.inset(top: 4)
                    }
                    
                    VStack(spacing: 6) {
                        Text("When NOT to use view reuse", font: .bodyBold)
                        Text("Avoid view reuse when:", font: .body).textColor(.secondaryLabel)
                        VStack(spacing: 4) {
                            Text("• Views are simple and cheap to create", font: .body)
                            Text("• State management becomes too complex", font: .body)
                            Text("• Each view has unique configuration that's hard to reset", font: .body)
                        }.inset(top: 4)
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("Basic usage", font: .bodyBold)
                        Code {
                            """
                            VStack {
                                for item in items {
                                    ItemComponent(item: item)
                                        .reuseKey("item-cell")  // Enable reuse
                                }
                            }
                            .scrollView()
                            
                            // Views are pooled and reused as you scroll
                            // Reduces view creation overhead
                            """
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("Custom view with prepareForReuse", font: .bodyBold)
                        Text("Implement the ReuseableView protocol to clean up state when a view is reused.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            class ItemCell: NSView, ReuseableView {
                                func prepareForReuse() {
                                    // Reset any state that shouldn't persist
                                    // Cancel pending operations
                                    // Clear cached data
                                }
                                
                                var item: Item? {
                                    didSet {
                                        componentEngine.component = VStack {
                                            Text(item?.title ?? "")
                                        }
                                    }
                                }
                            }
                            
                            VStack {
                                for item in items {
                                    ViewComponent<ItemCell>()
                                        .item(item)
                                        .size(width: .fill, height: 60)
                                        .reuseKey("item-cell")
                                }
                            }
                            """
                        }
                    }
                }
                .inset(16)
                .backgroundColor(.systemGreen.withAlphaComponent(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text("⚠️ Important: Modern iOS has optimized NSView creation", font: .bodyBold).textColor(.systemOrange)
                    Text("View reuse adds complexity and can introduce subtle bugs if state isn't properly managed. Only use it when you've identified view creation as a bottleneck through profiling. In most cases, the default behavior (no reuse) is the right choice.", font: .body).textColor(.secondaryLabel)
                }
                .inset(16)
                .backgroundColor(.systemOrange.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - Lazy Modifier
            
            VStack(spacing: 10) {
                Text("Lazy layout with .lazy modifier", font: .subtitle)
                Text("The .lazy modifier defers both layout calculation and rendering until a component becomes visible. This is powerful for complex layouts where the initial layout pass would be expensive.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("How it works", font: .bodyBold)
                        Text("Without .lazy, UIFoundationComponent calculates the layout for all components during the initial layout phase, even if they're not visible. With .lazy, you provide a size upfront, and the actual layout is deferred until the component scrolls into view.", font: .body).textColor(.secondaryLabel)
                    }
                    
                    Separator()
                    
                    VStack(spacing: 6) {
                        Text("Basic usage with fixed size", font: .bodyBold)
                        Code {
                            """
                            VStack {
                                for item in items {
                                    ComplexComponent(item: item)
                                        .lazy(width: .fill, height: 120)
                                }
                            }
                            .scrollView()
                            
                            // ComplexComponent layout is deferred until visible
                            // Initial scroll position loads instantly
                            """
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("Dynamic size with size provider", font: .bodyBold)
                        Text("When item sizes vary, use a size provider closure that calculates size based on the constraint.", font: .body).textColor(.secondaryLabel)
                        Code {
                            """
                            VStack {
                                for item in items {
                                    ComplexComponent(item: item)
                                        .lazy { constraint in
                                            let height = item.isExpanded ? 200 : 100
                                            return CGSize(
                                                width: constraint.maxWidth, 
                                                height: height
                                            )
                                        }
                                }
                            }
                            .scrollView()
                            """
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("When to use .lazy", font: .bodyBold)
                        VStack(spacing: 4) {
                            Text("✓ Components with expensive layout calculations", font: .body)
                            Text("✓ Long lists with complex item layouts", font: .body)
                            Text("✓ When you know item sizes in advance", font: .body)
                            Text("✗ Simple layouts (the overhead isn't worth it)", font: .body)
                            Text("✗ When sizes are truly dynamic and unpredictable", font: .body)
                        }
                    }
                }
                .inset(16)
                .backgroundColor(.systemPurple.withAlphaComponent(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 8) {
                    Text("💡 Tip: Size caching", font: .bodyBold)
                    Text("For components with expensive layout that don't change size often, consider implementing a size cache. Calculate and store each item's size once, then reuse it. This makes reloads much faster.", font: .body).textColor(.secondaryLabel)
                }
                .inset(16)
                .backgroundColor(.systemBlue.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - Async Layout
            
            VStack(spacing: 10) {
                Text("Async layout (Beta)", font: .subtitle)
                Text("Async layout moves the layout calculation to a background thread, keeping the main thread responsive during complex layout operations. Note that this doesn't make layout faster—it just prevents UI blocking.", font: .body).textColor(.secondaryLabel)
                
                VStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Text("Enabling async layout", font: .bodyBold)
                        Code {
                            """
                            class MyView: NSView {
                                override init(frame: CGRect) {
                                    super.init(frame: frame)
                                    componentEngine.asyncLayout = true
                                }
                                
                                override func updateProperties() {
                                    super.updateProperties()
                                    componentEngine.component = VStack {
                                        // Complex layout here
                                    }
                                }
                            }
                            """
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("Benefits", font: .bodyBold)
                        VStack(spacing: 4) {
                            Text("• Main thread stays responsive during layout", font: .body)
                            Text("• Smooth scrolling even with complex layouts", font: .body)
                            Text("• User can interact while layout completes", font: .body)
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("Important considerations", font: .bodyBold)
                        VStack(spacing: 4) {
                            Text("• Layout code must be thread-safe", font: .body)
                            Text("• Don't access UI properties during layout", font: .body)
                            Text("• View hierarchy updates asynchronously", font: .body)
                            Text("• Total layout time remains the same", font: .body)
                        }
                    }
                    
                    VStack(spacing: 6) {
                        Text("When to use async layout", font: .bodyBold)
                        VStack(spacing: 4) {
                            Text("✓ Layout takes > 16ms (causes frame drops)", font: .body)
                            Text("✓ User needs responsive UI during load", font: .body)
                            Text("✓ Your layout code is thread-safe", font: .body)
                            Text("✗ Layout is already fast", font: .body)
                            Text("✗ You need immediate layout results", font: .body)
                        }
                    }
                }
                .inset(16)
                .backgroundColor(.systemIndigo.withAlphaComponent(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - Practical Example
            
            VStack(spacing: 10) {
                Text("Practical example: Optimized list", font: .subtitle)
                Text("This example demonstrates a list optimized with the techniques covered above. Notice how smoothly it scrolls even with many items.", font: .body).textColor(.secondaryLabel)
                
                ViewComponent<OptimizedListExample>()
                    .size(width: 360, height: 400)
                
                Code(OptimizedListExample.codeRepresentation)
            }
            
            // MARK: - Best Practices
            
            VStack(spacing: 10) {
                Text("Best practices", font: .subtitle)
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "1.circle.fill")
                            .tintColor(.systemBlue)
                            .size(width: 24, height: 24)
                        VStack(spacing: 4) {
                            Text("Use ViewComponent generators", font: .bodyBold)
                            Text("Always prefer ViewComponent<ViewType>() or ViewComponent { ... } over creating view instances directly.", font: .body).textColor(.secondaryLabel)
                        }.flex()
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "2.circle.fill")
                            .tintColor(.systemGreen)
                            .size(width: 24, height: 24)
                        VStack(spacing: 4) {
                            Text("Profile before optimizing", font: .bodyBold)
                            Text("Use Instruments to identify actual bottlenecks. Don't optimize based on assumptions.", font: .body).textColor(.secondaryLabel)
                        }.flex()
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "3.circle.fill")
                            .tintColor(.systemOrange)
                            .size(width: 24, height: 24)
                        VStack(spacing: 4) {
                            Text("Keep it simple", font: .bodyBold)
                            Text("Complexity adds bugs. Use reuseKey and async layout only when measurements prove they're needed.", font: .body).textColor(.secondaryLabel)
                        }.flex()
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "4.circle.fill")
                            .tintColor(.systemPurple)
                            .size(width: 24, height: 24)
                        VStack(spacing: 4) {
                            Text("Leverage .lazy for expensive layouts", font: .bodyBold)
                            Text("When individual items have complex layout logic, .lazy can provide significant improvements.", font: .body).textColor(.secondaryLabel)
                        }.flex()
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "5.circle.fill")
                            .tintColor(.systemPink)
                            .size(width: 24, height: 24)
                        VStack(spacing: 4) {
                            Text("Keep custom component initialization lightweight", font: .bodyBold)
                            Text("When creating custom components, avoid heavy computations in init(). Instead, defer expensive work to layout(_:) time where you have access to constraints. For even more performance in a large list, implement a custom RenderNode to perform work at render time when the component becomes visible.", font: .body).textColor(.secondaryLabel)
                        }.flex()
                    }
                }
                .inset(16)
                .backgroundColor(.secondarySystemBackground)
                .cornerRadius(12)
            }
            
        }.inset(24).ignoreHeightConstraint().scrollView().fill()
    }
}

// MARK: - Example Views

@available(macOS 14.0, *)
@GenerateCode
final class OptimizedListExample: NSView {
    @Observable
    class ListViewModel {
        var items: [(title: String, detail: String)] = []
        
        init() {
            // Generate sample data
            items = (0..<100).map { index in
                ("Item \(index)", "Detail for item \(index) with some additional text to make it more interesting")
            }
        }
    }
    
    let viewModel = ListViewModel()
    
    override func updateProperties() {
        super.updateProperties()
        let viewModel = viewModel
        
        componentEngine.component = VStack(alignItems: .stretch) {
            // Header
            HStack(spacing: 10, justifyContent: .spaceBetween, alignItems: .center) {
                Text("Optimized List", font: .bodyBold)
                Text("\(viewModel.items.count) items", font: .caption)
                    .textColor(.secondaryLabel)
            }
            .inset(16)
            .backgroundColor(.systemGray6)
            
            Separator()

            VStack {
                for item in viewModel.items {
                    // Using ViewComponent generator pattern
                    // Views created only when visible
                    ViewComponent<OptimizedItemCell>()
                        .update { cell in
                            cell.configure(item.title, item.detail)
                        }
                        .size(width: .fill, height: 80)
                }
            }
            .scrollView()
            .flex()
        }
        .view()
        .clipsToBounds(true)
        .backgroundColor(.systemBackground)
        .cornerRadius(12)
        .borderWidth(1)
        .borderColor(.systemGray4)
    }
}

@available(macOS 14.0, *)
@GenerateCode
final class OptimizedItemCell: NSView {
    var itemTitle: String = ""
    var itemDetail: String = ""
    
    func configure(_ title: String, _ detail: String) {
        guard title != itemTitle || detail != itemDetail else { return }
        itemTitle = title
        itemDetail = detail
        
        componentEngine.component = HStack(spacing: 12, alignItems: .center) {
            Image(systemName: "doc.text", withConfiguration: NSImage.SymbolConfiguration(pointSize: 20, weight: .regular))
                .tintColor(.systemBlue)
            
            VStack(spacing: 4) {
                Text(title, font: .bodyBold)
                Text(detail, font: .caption)
                    .textColor(.secondaryLabel)
            }
            .flex()
            
            Image(systemName: "chevron.right")
                .tintColor(.tertiaryLabel)
        }
        .inset(h: 16, v: 12)
    }
}

