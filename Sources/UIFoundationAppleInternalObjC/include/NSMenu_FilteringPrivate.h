@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

typedef OSStatus (^CarbonEventHandler)(NSMenu *menu, EventHandlerCallRef handler, EventRef event);

@interface NSMenu ()
- (void)highlightItem:(nullable NSMenuItem *)item;
- (id)_handleCarbonEvents:(const struct EventTypeSpec *)events count:(unsigned long long)count handler:(CarbonEventHandler)handler;
@end

NS_ASSUME_NONNULL_END
