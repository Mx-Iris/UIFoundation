#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTableViewStyleData : NSObject <NSCopying>

@property NSTableViewStyle effectiveStyle;
@property NSTableViewRowSizeStyle rowSizeStyle;
@property (readonly) NSTableViewStyle tableViewStyle;
@property (readonly) BOOL hasInsetContent;
@property (readonly) BOOL hasPaddedContent;
@property (readonly) BOOL isSourceList;
@property double rowHeight;
@property double groupRowHeight;
@property double headerHeight;
@property CGSize intercellSpacing;
@property double intergroupSpacing;
@property double topPadding;
@property double bottomPadding;
@property BOOL wantsUniformInsetsForSingleColumn;
@property double rowContentPadding;
@property double rowContentInset;
@property double rowBackgroundInset;
@property double cornerRadius;
@property long long selectionMaterial;
@property double rowActionsGroupSpacing;
@property double rowActionButtonSpacing;
@property double rowActionButtonCornerRadius;
@property double indentationPerLevel;
@property double disclosureButtonLeadingSpacing;
@property double disclosureButtonWidth;
@property double disclosureButtonTrailingSpacing;

+ (instancetype)defaultStyleData;
- (instancetype)initWithEffectiveStyle:(NSTableViewStyle)effectiveStyle API_AVAILABLE(macos(11.0));
- (instancetype)initWithEffectiveStyle:(NSTableViewStyle)effectiveStyle rowSizeStyle:(NSTableViewRowSizeStyle)rowSizeStyle API_AVAILABLE(macos(11.0));

@end
NS_ASSUME_NONNULL_END
