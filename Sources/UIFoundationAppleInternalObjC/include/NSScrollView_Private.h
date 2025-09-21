//
//  NSScrollView_Private.h
//  UIFoundation
//
//  Created by JH on 2025/9/21.
//

#import <Cocoa/Cocoa.h>

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

NS_ASSUME_NONNULL_END
