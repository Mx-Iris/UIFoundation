@import Carbon;

NS_ASSUME_NONNULL_BEGIN

extern OSStatus HIMenuGetContentView(MenuRef inMenu, ThemeMenuType inMenuType, HIViewRef _Nonnull * _Nonnull outView);
extern OSStatus HIViewSetDrawingEnabled(HIViewRef inView, Boolean inEnabled);
extern OSStatus HIViewSetNeedsDisplay(HIViewRef inView, Boolean inNeedsDisplay);

NS_ASSUME_NONNULL_END
