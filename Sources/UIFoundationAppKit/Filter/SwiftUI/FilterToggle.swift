#if FilterUI

import SwiftUI

// TODO: convert to AppKit ><
@available(macOS 12.0, *)
public struct FilterToggle: View {
  let systemImage: String

  @Binding private var isOn: Bool
  @Environment(\.controlActiveState) private var activeState
  
  public init(systemImage: String, isOn: Binding<Bool>) {
    self.systemImage = systemImage
    _isOn = isOn
  }
    
  public var body: some View {
    SwiftUI.Button(action: { isOn.toggle() }) {
      SwiftUI.Image(systemName: systemImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 14, height: 14)
    }
    .frame(width: 22, height: 14)
    .buttonStyle(BorderlessButtonStyle())
    .tint(isOn ? Color.accentColor : nil)
    .symbolVariant(isOn ? SymbolVariants.fill : SymbolVariants.none)
    .opacity(activeState == .inactive ? 0.4 : 0.8)
  }
}

@available(macOS 12.0, *)
struct FilterToggle_Previews: PreviewProvider {
  static var previews: some View {
    FilterToggle(systemImage: "folder", isOn: .constant(false)).padding()
    FilterToggle(systemImage: "folder", isOn: .constant(true)).padding()
    FilterToggle(systemImage: "doc", isOn: .constant(false)).padding()
    FilterToggle(systemImage: "doc", isOn: .constant(true)).padding()
    FilterToggle(systemImage: "clock", isOn: .constant(false)).padding()
    FilterToggle(systemImage: "clock", isOn: .constant(true)).padding()
  }
}

#endif
