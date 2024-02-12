/*
    * This header is generated by classdump-dyld 1.0
    * Operating System: 14.2.1
    * Image Source: /System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore
    * classdump-dyld is licensed under GPLv3, Copyright © 2013-2016 by Elias Limneos.
    */

#import <QuartzCore/QuartzCore.h>
#import "NSViewLayerFilter.h"
#import <Foundation/Foundation.h>
@class NSString;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kCAFilterDarkenBlendMode;
extern NSString * const kCAFilterGaussianBlur;
extern NSString * const kCAFilterColorSaturate;
extern NSString * const kCAFilterLightenBlendMode;
extern NSString * const kCAFilterDestOver;

@interface CAFilter: NSObject <NSViewLayerFilter, NSCopying, NSMutableCopying, NSSecureCoding> {

	unsigned _type;
	NSString* _name;
	unsigned _flags;
	void* _attr;
	void* _cache;

}

@property (readonly) BOOL NS_isSourceOver; 
@property (readonly) NSString *type; 
@property (copy) NSString *name; 
@property (getter=isEnabled) BOOL enabled; 
@property  BOOL cachesInputImage; 
@property (getter=isAccessibility) BOOL accessibility; 
-(nullable instancetype)initWithType:(NSString *)arg1;
-(nullable instancetype)initWithName:(id)arg1;
+(BOOL)automaticallyNotifiesObserversForKey:(id)arg1;
+(BOOL)supportsSecureCoding;
+(id)filterWithType:(id)arg1;
+(id)filterWithName:(id)arg1;
+(void)CAMLParserStartElement:(id)arg1;
+(id)attributesForKey:(id)arg1;
+(id)filterTypes;
-(BOOL)NS_isSourceOver;
-(BOOL)enabled;
//-(Object*)CA_copyRenderValue;
-(void)setDefaults;
-(id)CAMLTypeForKey:(id)arg1;
-(void)CAMLParser:(id)arg1 setValue:(id)arg2 forKey:(id)arg3;
-(BOOL)isAccessibility;
-(id)attributesForKeyPath:(id)arg1;
-(BOOL)cachesInputImage;
-(void)encodeWithCAMLWriter:(id)arg1;
-(id)inputKeys;
-(id)outputKeys;
-(void)setAccessibility:(BOOL)arg1;
-(void)setCachesInputImage:(BOOL)arg1;

@end

NS_ASSUME_NONNULL_END
