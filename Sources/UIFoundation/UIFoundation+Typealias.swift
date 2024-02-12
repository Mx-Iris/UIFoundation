#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

public typealias NSUIView = NSView
public typealias NSUIViewController = NSViewController
public typealias NSUIStoryboard = NSStoryboard
public typealias NSUIStackView = NSStackView
public typealias NSUIStackViewOrientationOrAxis = NSUserInterfaceLayoutOrientation
public typealias NSUILayoutConstraintOrientationOrAxis = NSLayoutConstraint.Orientation
public typealias NSUILayoutPriority = NSLayoutConstraint.Priority
public typealias NSUIStackViewAlignment = NSLayoutConstraint.Attribute
public typealias NSUIStackViewDistribution = NSUIStackView.Distribution
public typealias NSUIEdgeInsets = NSEdgeInsets
public typealias NSUILayoutGuide = NSLayoutGuide
public typealias NSUIColor = NSColor
public typealias NSUIBezierPath = NSBezierPath
#endif

#if canImport(UIKit)
import UIKit

public typealias NSUIView = UIView
public typealias NSUIViewController = UIViewController
public typealias NSUIStoryboard = UIStoryboard
public typealias NSUIStackView = UIStackView
public typealias NSUIStackViewOrientationOrAxis = NSLayoutConstraint.Axis
public typealias NSUIStackViewAlignment = NSUIStackView.Alignment
public typealias NSUIStackViewDistribution = NSUIStackView.Distribution
public typealias NSUILayoutPriority = UILayoutPriority
public typealias NSUILayoutConstraintOrientationOrAxis = NSLayoutConstraint.Axis
public typealias NSUIEdgeInsets = UIEdgeInsets
public typealias NSUILayoutGuide = UILayoutGuide
public typealias NSUIColor = UIColor
public typealias NSUIBezierPath = UIBezierPath
#endif
