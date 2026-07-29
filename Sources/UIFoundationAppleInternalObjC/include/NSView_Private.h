#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

/// The kind of surface a view is drawn on. AppKit controls read it and change how they draw: a
/// pop-up button in the form context loses its bezel and shrinks to a label plus a chevron, a
/// segmented control in the toolbar context picks a different widget style, and so on.
///
/// A view inherits the context from the nearest ancestor that set one; `_semanticContext` is a
/// view's own explicit value, `_effectiveSemanticContext` the inherited result.
///
/// Only `NSViewSemanticContextForm` is Apple's own spelling (WebKit declares it in
/// `Source/WebCore/PAL/pal/spi/mac/NSViewSPI.h`). The other names are ours: AppKit's binary keeps
/// the type name but not the member names, and no Apple header outside WebKit's Form declaration
/// has surfaced. Every value below is pinned by AppKit's own code — either a `_setSemanticContext:`
/// call site in the framework or a reading taken off a view AppKit placed itself. See
/// `Researchs/AppKit-NSView-SemanticContext.md` for the evidence behind each row.
///
/// **These numbers are not contractual.** Comparing today's readings against the enum published in
/// the Parrot app circa 2017 shows the assignments from 2 upwards have moved. Treat anything other
/// than `NSViewSemanticContextForm` — stable since macOS 13, and still hardcoded by WebKit — as
/// something to re-verify on a new OS release.
typedef NS_ENUM(NSInteger, NSViewSemanticContext) {
    /// No explicit context: the view inherits from its nearest ancestor that set one. This is what
    /// `+[NSView default_semanticContext]` returns, and every view's `_semanticContext` until set.
    NSViewSemanticContextNone = 0,
    /// Ordinary window content — where a view lands when nothing above it asked for anything else.
    NSViewSemanticContextNormal = 1,
    /// The system status bar. `NSStatusBarButton` resolves here.
    NSViewSemanticContextStatusBar = 2,
    /// A window's title bar. `NSTitlebarView` resolves here, as does an inspector bar and (on
    /// macOS 26) a title bar accessory.
    NSViewSemanticContextTitlebar = 3,
    /// A window toolbar. `-[NSToolbarView initWithFrame:]` sets this on itself, so everything
    /// hosted in an `NSToolbarItem` inherits it.
    NSViewSemanticContextToolbar = 4,
    /// The label and icon inside a source-list row — not the list itself, which is
    /// `NSViewSemanticContextSidebar`. `-[NSTableCellView _updateSourceListAttributesInRowView:]`
    /// stamps this onto the cell's `textField` and `imageView`.
    NSViewSemanticContextSourceListCell = 5,
    /// A menu. AppKit's menu window background views set this; so does Shortcut.framework's
    /// `SCTMenuView`.
    NSViewSemanticContextMenu = 6,
    /// A sidebar. `-[_NSSplitViewItemViewWrapper setSidebar:]` sets it, so everything inside an
    /// `NSSplitViewItem` sidebar — including a source-list table — inherits it.
    NSViewSemanticContextSidebar = 7,
    /// A grouped settings form — what SwiftUI's `Form` puts its rows in, and what makes a pop-up
    /// button drop its bezel. macOS 13 and later.
    NSViewSemanticContextForm = 8,
};

@interface NSView ()

- (NSView *)_findLastViewInKeyViewLoop;

/// This view's own context, or `NSViewSemanticContextNone` when it has not asked for one.
/// Setting it applies to the whole subtree: descendants inherit unless they set their own.
///
/// Controls read the context while drawing, so changing it on a live hierarchy needs a redraw to
/// take effect. AppKit drives its own controls off change notifications for exactly this reason
/// (`_controlViewDidChangeEffectiveSemanticContext:`).
@property (nonatomic, setter=_setSemanticContext:) NSViewSemanticContext _semanticContext;

/// The context actually in force: this view's own value, or the nearest explicit ancestor's.
@property (nonatomic, readonly) NSViewSemanticContext _effectiveSemanticContext;

@end


@interface NSView () <CALayerDelegate>
@end

@interface NSView (SubviewsIvar)
@property (assign, setter=_setSubviewsIvar:) NSMutableArray<__kindof NSView *> *_subviewsIvar;
@end

@interface NSView ()

//@property (copy, nullable) NSColor *backgroundColor;
//
//@property CGFloat cornerRadius;

@property (strong, nullable) NSView *maskView;

@property (nonatomic) CGAffineTransform frameTransform;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif
