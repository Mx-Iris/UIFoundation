#if FilterUI

import SwiftUI

// TODO: refactor API for filter buttons
// TODO: remove filter field style?
// TODO: add API for filter token field

/// Contains the possible style values for a filter field.
public enum FilterFieldStyle {
  /// The filter field style resolves to a plain style.
  case plain
  /// The filter field style resolves to a source-list style.
  case sourceList
}

/// A control that displays an editable text interface optimized for performing text-based filtering.
public struct FilterField<Accessory: View>: NSViewRepresentable {
  @Binding var text: String
  var prompt: LocalizedStringKey? = nil
  var isFiltering: Bool // TODO: do this with preference values instead
  var onMake: ((_ searchField: FilterSearchField) -> Void)?
  var onCommit: ((_ text: String) -> Void)?
  var accessory: Accessory
  @Environment(\.filterFieldStyle) private var style
  @Environment(\.controlSize) private var controlSize

  public init(
    text: Binding<String>,
    prompt: LocalizedStringKey? = nil,
    isFiltering: Bool? = nil,
    onMake: ((_ searchField: FilterSearchField) -> Void)? = nil,
    onCommit: ((_ text: String) -> Void)? = nil
  ) where Accessory == EmptyView {
    self.init(
      text: text,
      prompt: prompt,
      isFiltering: isFiltering,
      accessory: { EmptyView() },
      onMake: onMake,
      onCommit: onCommit
    )
  }
  
  public init(
    text: Binding<String>,
    prompt: LocalizedStringKey? = nil,
    isFiltering: Bool? = nil,
    @ViewBuilder accessory: () -> Accessory,
    onMake: ((_ searchField: FilterSearchField) -> Void)? = nil,
    onCommit: ((_ text: String) -> Void)? = nil
  ) {
    _text = text
    self.prompt = prompt
    self.isFiltering = isFiltering ?? false
    self.accessory = accessory()
    self.onMake = onMake
    self.onCommit = onCommit
  }
  
  public func makeNSView(context: Context) -> FilterSearchField {
    let view = FilterSearchField()
    view.placeholderString = prompt?.string
    view.delegate = context.coordinator
    onMake?(view)
    return view
  }
  
  public func updateNSView(_ view: FilterSearchField, context: Context) {
    view.placeholderString = prompt?.string
    view.stringValue = text
    view.isFiltering = isFiltering
    view.controlSize = controlSize.nsControlSize
    view.hasSourceListAppearance = style == .sourceList
//    // TODO: profile performance of this
//    if type(of: accessory) != EmptyView.self {
//      view.accessoryView = NSHostingView(rootView: accessory)
//    } else {
////    if type(of: accessory) == EmptyView.self {
//      view.accessoryView = nil
//    }
  }
  
  public func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }
  
  public final class Coordinator: NSObject, NSSearchFieldDelegate {
    let parent: FilterField
    
    init(parent: FilterField) {
      self.parent = parent
    }
    
    public func controlTextDidBeginEditing(_ notification: Notification) {
//      let view = notification.object as! FilterSearchField
    }
    
    public func controlTextDidChange(_ notification: Notification) {
      let view = notification.object as! FilterSearchField
      parent.text = view.objectValue as? String ?? ""
    }
    
    public func controlTextDidEndEditing(_ notification: Notification) {
      let view = notification.object as! FilterSearchField
      parent.onCommit?(view.stringValue)
    }
  }
}

extension LocalizedStringKey {
  var key: String {
    Mirror(reflecting: self).children.first { $0.label == "key" }?.value as? String ?? ""
  }

  var string: String {
    NSLocalizedString(key, comment: "")
  }
}

#endif
