#if FilterUI

import SwiftUI

struct FilterFieldStyleKey: EnvironmentKey {
  static var defaultValue = FilterFieldStyle.plain
}

public extension EnvironmentValues {
  var filterFieldStyle: FilterFieldStyle {
    get { self[FilterFieldStyleKey.self] }
    set { self[FilterFieldStyleKey.self] = newValue }
  }
}

public extension View {
  func filterFieldStyle(_ value: FilterFieldStyle) -> some View {
    environment(\.filterFieldStyle, value)
  }
}

#endif
