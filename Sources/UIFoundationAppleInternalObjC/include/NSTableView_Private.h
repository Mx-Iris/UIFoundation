#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

@class NSTableViewStyleData;

NS_ASSUME_NONNULL_BEGIN

@interface NSTableView ()

@property (nonatomic, strong, setter=_setStyleData:, getter=_styleData) NSTableViewStyleData *_styleData;

/// Whether rows the table has not measured yet are placed at an estimated height, the estimate
/// being corrected as rows get measured.
///
/// `-setDelegate:` asks for it every time the delegate changes (on `NSTableView` and on
/// `NSOutlineView`). The request is granted only for a view-based table whose rows can differ in
/// height (`-_supportsVariableHeightRows`: group rows, a height-of-row delegate method, a
/// `rowSizeStyle` other than custom, spacing between groups, or automatic row heights), and only
/// while the `NSTableViewCanEstimateRowHeights` default is not `NO`. Switching it discards the
/// table's row geometry but neither reloads the table nor moves the row views on screen: rows
/// placed from an estimate stay where it put them until the table reloads.
///
/// Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md
@property (nonatomic, setter=_setEstimatesRowHeights:, getter=_estimatesRowHeights) BOOL _estimatesRowHeights;

@end

NS_ASSUME_NONNULL_END

#endif
