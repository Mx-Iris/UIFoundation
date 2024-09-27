//
//  _NSSimpleImageView.h
//  
//
//  Created by JH on 2024/9/27.
//

#import <Cocoa/Cocoa.h>
#import <Symbols/Symbols.h>

NS_ASSUME_NONNULL_BEGIN

@interface _NSSimpleImageView : NSView
@property (readonly, nonatomic, nullable) NSImage *image;
/// Adds a symbol effect to the image view with specified options and animation.
- (void)addSymbolEffect:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated API_AVAILABLE(macos(14.0));
/// Removes from the image view the symbol effect matching the type of effect passed in, with specified options and animation.
- (void)removeSymbolEffectOfType:(NSSymbolEffect *)symbolEffect options:(NSSymbolEffectOptions *)options animated:(BOOL)animated API_AVAILABLE(macos(14.0));
/// Sets the symbol image on the image view with a symbol content transition and specified options.
/// Passing in a non-symbol image will result in undefined behavior.
- (void)setSymbolImage:(NSImage *)symbolImage withContentTransition:(NSSymbolContentTransition *)transition options:(NSSymbolEffectOptions *)options API_AVAILABLE(macos(14.0));
@end

NS_ASSUME_NONNULL_END
