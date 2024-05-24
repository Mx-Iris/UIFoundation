#import <QuartzCore/QuartzCore.h>

struct CAColorMatrix {
    float m11, m12, m13, m14, m15;
    float m21, m22, m23, m24, m25;
    float m31, m32, m33, m34, m35;
    float m41, m42, m43, m44, m45;
};
typedef struct CAColorMatrix CAColorMatrix;

@class NSString;
@protocol CABackdropLayerDelegate, CALayerDelegate;

@protocol CABackdropLayerDelegate <CALayerDelegate>

@end

@interface CABackdropLayer : CALayer

@property (class, readonly, copy, nonatomic) NSString *mt_keyPathForColorMatrixDrivenOpacity;
@property (class, readonly, copy, nonatomic) NSString *mt_keyPathForColorMatrixDrivenInoperativeOpacity;

@property (readonly, nonatomic) double mt_colorMatrixDrivenOpacity;
@property (readonly, nonatomic) double mt_colorMatrixDrivenInoperativeOpacity;
@property (getter=isEnabled) BOOL enabled;
@property (copy) NSString *groupName;
@property BOOL usesGlobalGroupNamespace;
@property (copy) NSString *groupNamespace;
@property double scale;
@property CGRect backdropRect;
@property double marginWidth;
@property BOOL disablesOccludedBackdropBlurs;
@property BOOL captureOnly;
@property BOOL allowsInPlaceFiltering;
@property BOOL reducesCaptureBitDepth;
@property BOOL ignoresScreenClip;
@property double bleedAmount;
@property BOOL windowServerAware;
@property (getter=isInverseMeshed) BOOL inverseMeshed;
@property BOOL allowsSubstituteColor;
@property struct CGColor { } *substituteColor;
@property BOOL ignoresOffscreenGroups;
@property double zoom;
@property (weak) id<CABackdropLayerDelegate> delegate;

+ (CAColorMatrix)mt_colorMatrixForOpacity:(double)a0;
+ (id)mt_orderedFilterTypes;
+ (id)mt_orderedFilterTypesBlurAtEnd;

- (void)_mt_applyFilterDescription:(id)a0 remainingExistingFilters:(id)a1 filterOrder:(id)a2 removingIfIdentity:(BOOL)a3;
- (void)_mt_configureFilterOfType:(id)a0 ifNecessaryWithFilterOrder:(id)a1;
- (void)_mt_configureFilterOfType:(id)a0 ifNecessaryWithName:(id)a1 andFilterOrder:(id)a2;
- (void)_mt_removeFilterOfType:(id)a0 ifNecessaryWithName:(id)a1;
- (void)_mt_removeFilterOfTypeIfNecessary:(id)a0;
- (void)_mt_setColorMatrix:(CAColorMatrix)a0 withName:(id)a1 filterOrder:(id)a2 removingIfIdentity:(BOOL)a3;
- (void)_mt_setValue:(id)a0 forFilterOfType:(id)a1 valueKey:(id)a2 filterOrder:(id)a3 removingIfIdentity:(BOOL)a4;
- (void)mt_applyMaterialDescription:(id)a0 removingIfIdentity:(BOOL)a1;
- (void)mt_setColorMatrixDrivenInoperativeOpacity:(double)a0 removingIfIdentity:(BOOL)a1;
- (void)mt_setColorMatrixDrivenOpacity:(double)a0 removingIfIdentity:(BOOL)a1;

@end
