#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTableViewStyleData : NSObject <NSCopying>

@property NSTableViewStyle effectiveStyle API_AVAILABLE(macos(11.0));
@property NSTableViewRowSizeStyle rowSizeStyle;
@property (readonly) NSTableViewStyle tableViewStyle API_AVAILABLE(macos(11.0));
@property (readonly) BOOL hasInsetContent;
@property (readonly) BOOL hasPaddedContent;
@property (readonly) BOOL isSourceList;
@property CGFloat rowHeight;
@property CGFloat groupRowHeight;
@property CGFloat headerHeight;
@property CGSize intercellSpacing;
@property CGFloat intergroupSpacing;
@property CGFloat topPadding;
@property CGFloat bottomPadding;
@property BOOL wantsUniformInsetsForSingleColumn;
@property CGFloat rowContentPadding;
@property CGFloat rowContentInset;
@property CGFloat rowBackgroundInset;
@property CGFloat cornerRadius;
@property NSInteger selectionMaterial;
@property CGFloat rowActionsGroupSpacing;
@property CGFloat rowActionButtonSpacing;
@property CGFloat rowActionButtonCornerRadius;
@property CGFloat indentationPerLevel;
@property CGFloat disclosureButtonLeadingSpacing;
@property CGFloat disclosureButtonWidth;
@property CGFloat disclosureButtonTrailingSpacing;

+ (instancetype)defaultStyleData;
- (instancetype)initWithEffectiveStyle:(NSTableViewStyle)effectiveStyle API_AVAILABLE(macos(11.0));
- (instancetype)initWithEffectiveStyle:(NSTableViewStyle)effectiveStyle rowSizeStyle:(NSTableViewRowSizeStyle)rowSizeStyle API_AVAILABLE(macos(11.0));

@end
NS_ASSUME_NONNULL_END

#endif
