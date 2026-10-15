#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSScrollViewDelegate <NSObject>

@property (setter=_setWantsPageAlignedHorizontalAxis:) BOOL _wantsPageAlignedHorizontalAxis;
@property (setter=_setWantsPageAlignedVerticalAxis:) BOOL _wantsPageAlignedVerticalAxis;

@optional

- (void)didScrollInScrollView:(NSScrollView *)scrollView;
- (BOOL)allowPanningInScrollView:(NSScrollView *)scrollView;
- (void)didBeginScrollInScrollView:(NSScrollView *)scrollView;
- (void)didEndScrollInScrollView:(NSScrollView *)scrollView;
- (id)magnificationInflectionPointsForScrollView:(NSScrollView *)scrollView;
- (void)scrollView:(NSScrollView *)scrollView didChangePresentationOrigin:(CGPoint)presentationOrigin active:(BOOL)active;
- (CGFloat)scrollView:(NSScrollView *)scrollView pageAlignedOriginOnAxis:(long long)axis forProposedDestination:(CGFloat)proposedDestination currentOrigin:(CGFloat)currentOrigin initialOrigin:(CGFloat)initialOrigin velocity:(CGFloat)velocity;
- (void)scrollViewBeganMomentum:(NSScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset;

@end

@interface NSScrollView ()

@property (nonatomic) BOOL pagingEnabled;
@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@property (weak, nullable) id<NSScrollViewDelegate> delegate;

@property BOOL hasTopShadow;
@property BOOL hasBottomShadow;
@property double topShadowTopInset;
@property double topShadowMinimumRequiredContentYOffset;
@property long long alwaysShownPocketEdges;
@property long long allowedPocketEdges;
@property (copy, nullable) NSColor *scrollerKnobColor;
@property (copy, nullable) NSColor *scrollerTrackColor;
@property (nonatomic, setter=_setAllowsContentUnderLegacyScrollers:) BOOL _allowsContentUnderLegacyScrollers;
@property double decelerationRate;
@property double horizontalScrollDecelerationFactor;
@property double verticalScrollDecelerationFactor;
@property BOOL hasHorizontalMoreContentIndicators;
@property (nonatomic, setter=_setContentExtendsUnderHeader:) BOOL _contentExtendsUnderHeader;
@property (nonatomic, setter=_setContentExtendsPastContentInsets:) BOOL _contentExtendsPastContentInsets;
@property (readonly) NSEdgeInsets _automaticContentInsets;
@property (nonatomic, setter=_setAllowsAdditionalContentInsetsForCornerRadii:) BOOL _allowsAdditionalContentInsetsForCornerRadii;
@property (nonatomic) BOOL autoforwardsScrollWheelEvents;
@property (strong, nonatomic, setter=_setLineBorderColor:, nullable) NSColor *_lineBorderColor;
@property (readonly) BOOL _usesOverlayScrollers;
@property (nonatomic) BOOL drawsContentShadow;

@end

/// Scroll pockets: the scroll edge effect AppKit draws along the top and the bottom edge of a scroll view
/// from macOS 26 on, where content scrolls under a bar. Each pocket is an `NSScrollPocket` view the scroll view
/// adds to itself. A window registers its title bar with a scroll view that reaches it, and a split view item
/// registers its accessories; nothing else is registered for you.
///
/// An `edge` argument is 0 for the top edge and 1 for the bottom one; `alwaysShownPocketEdges` and
/// `allowedPocketEdges` take one bit per edge, `1 << edge`. Measured on macOS 27.2:
///
/// - The bottom pocket exists only while a container is registered on the bottom edge or the edge is always
///   shown. It is as tall as the scroll view's own bottom content inset — not its clip view's: a clip view inset
///   with none on the scroll view leaves the pocket 0 points tall — united with the containers registered there.
/// - The top pocket is as tall as the scroll view's top safe area inset — not its content inset — united with
///   the containers registered on the top edge.
///
/// Read off macOS 27.0's AppKit; Xcode 27.2 calls all of these from macOS 26 on. macOS 27.0 also has a
/// `_registeredPocketContainersOnEdge:`, which 27.2 does not. See
/// `Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`.
@interface NSScrollView ()

/// Registers `container`, a view that floats over the given edge, with that edge's pocket, which then reaches
/// at least to the far side of the container.
- (void)registerPocketContainer:(NSView *)container onEdge:(NSInteger)edge API_AVAILABLE(macos(26.0));

/// Undoes `registerPocketContainer:onEdge:`.
- (void)unregisterPocketContainer:(NSView *)container onEdge:(NSInteger)edge API_AVAILABLE(macos(26.0));

/// The style of the pocket on the given edge, 0 on both edges until set. What each value draws has not been
/// worked out; Xcode 27 sets 2 on the top edge of a navigator whose chooser shows a second level and 0
/// otherwise, and 2 on both edges on macOS 26.
- (NSInteger)scrollPocketStyleOnEdge:(NSInteger)edge API_AVAILABLE(macos(26.0));
- (void)setScrollPocketStyle:(NSInteger)style onEdge:(NSInteger)edge API_AVAILABLE(macos(26.0));

/// The pocket view on the given edge, made when `makeIfNeeded` is `YES` and it does not exist yet.
- (nullable __kindof NSView *)_pocketForEdge:(NSInteger)edge makeIfNeeded:(BOOL)makeIfNeeded API_AVAILABLE(macos(26.0));

@end

NS_ASSUME_NONNULL_END

#endif
