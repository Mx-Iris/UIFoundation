#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

typedef NS_ENUM(NSInteger, NSViewSemanticContext) {
    NSViewSemanticContextForm = 8,
};

@interface NSView ()

- (NSView *)_findLastViewInKeyViewLoop;

@property (nonatomic, setter=_setSemanticContext:) NSViewSemanticContext _semanticContext;

@end


@interface NSView () <CALayerDelegate>
@end

@interface NSView (SubviewsIvar)
@property (assign, setter=_setSubviewsIvar:) NSMutableArray<__kindof NSView *> *_subviewsIvar;
@end

@interface NSView ()

//@property (copy, nullable) NSColor *backgroundColor;
//
//@property CGFloat cornerRadius;

@property (strong, nullable) NSView *maskView;

@property (nonatomic) CGAffineTransform frameTransform;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif
