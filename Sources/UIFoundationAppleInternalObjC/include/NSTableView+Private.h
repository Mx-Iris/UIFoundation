#import <Cocoa/Cocoa.h>

@class NSTableViewStyleData;

NS_ASSUME_NONNULL_BEGIN

@interface NSTableView (__PrivateSPI)
@property (nonatomic, strong, setter=_setStyleData:, getter=_styleData) NSTableViewStyleData *_styleData;
@end

NS_ASSUME_NONNULL_END
