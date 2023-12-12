#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class SegmentedControl: NSSegmentedControl {
    public convenience init(labels: [String], trackingMode: NSSegmentedControl.SwitchTracking, segmentStyle: NSSegmentedControl.Style) {
        self.init(labels: labels, trackingMode: trackingMode, target: nil, action: nil)
        self.segmentStyle = segmentStyle
    }
}

#endif
