#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

/// The view AppKit draws a scroll edge effect with, from macOS 26 on: a scroll view adds one along an edge
/// (`-[NSScrollView _pocketForEdge:makeIfNeeded:]`), and Xcode 27.2 also makes its own, outside any scroll view, to lay
/// over its editor area and behind its editor bars (`DVTEdgeOcclusionView`). Written in Swift inside AppKit; the class
/// is exported (AppKit's `.tbd` lists it under `objc-classes`). Only the members a stand-alone pocket needs are declared.
/// Read off macOS 27.2: `Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`, section 5.
API_AVAILABLE(macos(26.0))
@interface NSScrollPocket : NSView

/// The edge the effect fades towards: 0 the top, 1 the bottom, as `-[NSScrollView registerPocketContainer:onEdge:]`.
@property (nonatomic) NSInteger edge;

/// 0 by default. 2 draws the hard effect — the content blurred under a near-opaque replay of the background — whatever
/// the pocket's elements; 0 and 1 leave the choice to its elements, and a pocket with none draws nothing. 3 and above
/// trap on macOS 27.2.
@property (nonatomic) NSInteger style;

/// Whether a hairline is drawn along the far side of the pocket. Xcode 27 turns it off on its own pockets.
@property (nonatomic) BOOL allowsSeparator;

/// The backdrop group the pocket blurs the content behind it in. When `nil`, a pocket with the title bar among its
/// containers takes the nearest `_titlebarGroupName` up its superview chain, and any other one a name of its own.
@property (nonatomic, copy, nullable) NSString *backdropGroupName;

/// A capture-only backdrop the pocket replays the background from. A scroll view puts its pocket's behind its clip view;
/// the host of a stand-alone pocket puts it behind the content the pocket covers.
@property (nonatomic, readonly) NSView *captureView;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif
