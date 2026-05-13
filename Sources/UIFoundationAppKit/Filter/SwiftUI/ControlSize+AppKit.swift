#if FilterUI

import SwiftUI

extension ControlSize {
  var nsControlSize: NSControl.ControlSize {
    switch self {
    case .regular: return .regular
    case .small: return .small
    case .mini: return .mini
    case .large:
      if #available(macOS 11.0, *) { return .large }
      return .regular
    case .extraLarge:
      if #available(macOS 26.0, *) { return .extraLarge }
      if #available(macOS 11.0, *) { return .large }
      return .regular
    @unknown default: return .regular
    }
  }
}

#endif
