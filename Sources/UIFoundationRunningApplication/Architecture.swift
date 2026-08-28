#if RunningApplication && os(macOS)

public enum Architecture: CustomStringConvertible, Hashable, Sendable {
    case x86_64
    case arm64
    case arm64e
    case i386
    case ppc
    case ppc64
    case unknown

    public var description: String {
        switch self {
        case .x86_64:
            "x64"
        case .arm64:
            "arm64"
        case .arm64e:
            "arm64e"
        case .i386:
            "i386"
        case .ppc:
            "PPC"
        case .ppc64:
            "PPC64"
        case .unknown:
            "Unknown"
        }
    }
}

#endif
