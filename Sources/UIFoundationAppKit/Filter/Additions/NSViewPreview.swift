#if FilterUI

import SwiftUI

public struct NSViewPreview<View: NSView>: NSViewRepresentable {
  let view: View

  public init(_ builder: @escaping () -> View) {
    view = builder()
  }

  public init(_ setUp: ((View) -> ())? = nil) {
    view = View()
    setUp?(view)
  }

  public func makeNSView(context: Context) -> NSView {
    view
  }

  public func updateNSView(_ view: NSView, context: Context) {
    view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    view.setContentHuggingPriority(.defaultHigh, for: .vertical)
  }
}

#endif
