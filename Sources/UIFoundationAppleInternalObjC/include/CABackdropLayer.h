#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

typedef struct CAColorMatrix {
    float m11, m12, m13, m14, m15;
    float m21, m22, m23, m24, m25;
    float m31, m32, m33, m34, m35;
    float m41, m42, m43, m44, m45;
} CAColorMatrix;

@protocol CABackdropLayerDelegate <CALayerDelegate>

@end

@interface CABackdropLayer : CALayer

@property (getter=isEnabled) BOOL enabled;
@property (copy, nullable) NSString *groupName;
@property BOOL usesGlobalGroupNamespace;
@property (copy, nullable) NSString *groupNamespace;
@property CGFloat scale;
@property CGRect backdropRect;
@property CGFloat marginWidth;
@property BOOL disablesOccludedBackdropBlurs;
@property BOOL captureOnly;
@property BOOL allowsInPlaceFiltering;
@property BOOL reducesCaptureBitDepth;
@property BOOL ignoresScreenClip;
@property CGFloat bleedAmount;
@property BOOL windowServerAware;
@property (getter=isInverseMeshed) BOOL inverseMeshed;
@property BOOL allowsSubstituteColor;
@property (nullable) CGColorRef substituteColor;
@property BOOL ignoresOffscreenGroups;
@property CGFloat zoom;
@property (weak, nullable) id<CABackdropLayerDelegate> delegate;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif
