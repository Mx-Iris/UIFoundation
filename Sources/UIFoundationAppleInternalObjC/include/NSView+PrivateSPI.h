#import <AppKit/AppKit.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@interface NSView ()

@property (copy, nullable) NSColor *backgroundColor;

@property CGFloat cornerRadius;

@property (strong, nullable) NSView *maskView;

@property (nonatomic) CGAffineTransform frameTransform;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
