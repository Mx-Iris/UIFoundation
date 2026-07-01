#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage ()
+ (instancetype)imageWithImageRep:(NSImageRep *)imageRep;
- (void)lockFocusWithRect:(NSRect)rect context:(nullable NSGraphicsContext *)context hints:(nullable NSDictionary *)hints flipped:(BOOL)flipped;
@end

@interface NSImage (NSSystemSymbols)
+ (nullable instancetype)imageWithPrivateSystemSymbolName:(NSString *)name;
+ (nullable instancetype)imageWithPrivateSystemSymbolName:(NSString *)name accessibilityDescription:(nullable NSString *)description;
+ (nullable instancetype)imageWithPrivateSystemSymbolName:(NSString *)name variableValue:(double)value API_AVAILABLE(macos(13.0));
+ (nullable instancetype)imageWithPrivateSystemSymbolName:(NSString *)name variableValue:(double)value accessibilityDescription:(nullable NSString *)description API_AVAILABLE(macos(13.0));
@end

NS_ASSUME_NONNULL_END

#endif
