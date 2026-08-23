#if WelcomePanel && os(macOS)

import Foundation

extension Bundle {
    var appName: String {
        infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
    }

    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

#endif
