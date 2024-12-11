#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

@class NSTableViewStyleData;

NS_ASSUME_NONNULL_BEGIN

@interface NSTableView ()

@property (nonatomic, strong, setter=_setStyleData:, getter=_styleData) NSTableViewStyleData *_styleData;

@end

NS_ASSUME_NONNULL_END

#endif
