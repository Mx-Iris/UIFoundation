#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

public typealias _NSUIView = NSView
public typealias _NSUIViewController = NSViewController
public typealias _NSUIStoryboard = NSStoryboard
public typealias _NSUIStackView = NSStackView
public typealias _NSUIStackViewOrientationOrAxis = NSUserInterfaceLayoutOrientation
public typealias _NSUILayoutConstraintOrientationOrAxis = NSLayoutConstraint.Orientation
public typealias _NSUILayoutPriority = NSLayoutConstraint.Priority
public typealias _NSUIStackViewAlignment = NSLayoutConstraint.Attribute
public typealias _NSUIStackViewDistribution = _NSUIStackView.Distribution
public typealias _NSUIEdgeInsets = NSEdgeInsets
public typealias _NSUILayoutGuide = NSLayoutGuide
public typealias _NSUIColor = NSColor
public typealias _NSUIBezierPath = NSBezierPath
#endif

#if canImport(UIKit)
import UIKit

public typealias _NSUIView = UIView
public typealias _NSUIViewController = UIViewController
public typealias _NSUIStoryboard = UIStoryboard
public typealias _NSUIStackView = UIStackView
public typealias _NSUIStackViewOrientationOrAxis = NSLayoutConstraint.Axis
public typealias _NSUIStackViewAlignment = _NSUIStackView.Alignment
public typealias _NSUIStackViewDistribution = _NSUIStackView.Distribution
public typealias _NSUILayoutPriority = UILayoutPriority
public typealias _NSUILayoutConstraintOrientationOrAxis = NSLayoutConstraint.Axis
public typealias _NSUIEdgeInsets = UIEdgeInsets
public typealias _NSUILayoutGuide = UILayoutGuide
public typealias _NSUIColor = UIColor
public typealias _NSUIBezierPath = UIBezierPath
#endif
