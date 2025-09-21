//
//  NSImage+Private.h
//  UIFoundation
//
//  Created by JH on 2025/9/21.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage ()
+ (instancetype)imageWithImageRep:(NSImageRep *)imageRep;
- (void)lockFocusWithRect:(NSRect)rect context:(nullable NSGraphicsContext *)context hints:(nullable NSDictionary *)hints flipped:(BOOL)flipped;
@end

@interface NSImage (NSSystemSymbols)
+ (nullable instancetype)imageWithPrivateSystemSymbolName:(NSString *)name accessibilityDescription:(nullable NSString *)description;
@end

NS_ASSUME_NONNULL_END
