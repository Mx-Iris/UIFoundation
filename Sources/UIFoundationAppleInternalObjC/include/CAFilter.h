#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

@class NSString;

NS_ASSUME_NONNULL_BEGIN

CA_EXTERN NSString *const kCAFilterDarkenBlendMode;
CA_EXTERN NSString *const kCAFilterGaussianBlur;
CA_EXTERN NSString *const kCAFilterColorSaturate;
CA_EXTERN NSString *const kCAFilterLightenBlendMode;
CA_EXTERN NSString *const kCAFilterDestOver;

@class NSString;

@interface CAFilter : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>

@property (readonly, nullable) NSString *type;
@property (copy, nullable) NSString *name;
@property (getter = isEnabled) BOOL enabled;
@property BOOL cachesInputImage;
@property (getter = isAccessibility) BOOL accessibility;

+ (nullable instancetype)filterWithName:(id)name;
+ (nullable instancetype)filterWithType:(id)type;
- (nullable instancetype)initWithName:(id)name;
- (nullable instancetype)initWithType:(id)type;
+ (nullable id)attributesForKey:(id)key;
+ (nullable id)filterTypes;
- (BOOL)enabled;
- (void)setDefaults;
- (nullable id)attributesForKeyPath:(id)keyPath;
- (nullable id)inputKeys;
- (nullable id)outputKeys;

@end


NS_ASSUME_NONNULL_END

#endif
