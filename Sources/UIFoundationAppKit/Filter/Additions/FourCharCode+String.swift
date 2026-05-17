#if FilterUI && os(macOS)

import Carbon

// Useful when debugging.

extension FourCharCode {
    var string: String? {
        String(
            cString: [
                CChar(self >> 24 & 0xFF),
                CChar(self >> 16 & 0xFF),
                CChar(self >> 8 & 0xFF),
                CChar(self & 0xFF),
                0,
            ],
            encoding: .ascii
        )
    }
}

#endif
