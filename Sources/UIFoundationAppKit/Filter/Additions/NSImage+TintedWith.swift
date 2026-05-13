#if FilterUI

import AppKit

extension NSImage {
  func tinted(with color: NSColor) -> NSImage {
    return NSImage(size: size, flipped: false) { rect in
      color.set()
      rect.fill()
      self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .destinationIn, fraction: 1)
      return true
    }
  }
}

#endif
