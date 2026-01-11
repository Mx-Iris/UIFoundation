#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox<NSSound> {
    /// The name of a sound.
    enum SoundName: String, Hashable, CaseIterable {
        /// Basso
        case basso = "Basso"
        /// Blow
        case blow = "Blow"
        /// Bottle
        case bottle = "Bottle"
        /// Frog
        case frog = "Frog"
        /// Funk
        case funk = "Funk"
        /// Glass
        case glass = "Glass"
        /// Hero
        case hero = "Hero"
        /// Morse
        case morse = "Morse"
        /// Ping
        case ping = "Ping"
        /// Pop
        case pop = "Pop"
        /// Purr
        case purr = "Purr"
        /// Sosumi
        case sosumi = "Sosumi"
        /// Submarine
        case submarine = "Submarine"
        /// Tink
        case tink = "Tink"
    }

    /// The sound with the name "Basso".
    public static let basso = NSSound(named: .basso)
    /// The sound with the name "Blow".
    public static let blow = NSSound(named: .blow)
    /// The sound with the name "Bottle".
    public static let bottle = NSSound(named: .bottle)
    /// The sound with the name "Frog".
    public static let frog = NSSound(named: .frog)
    /// The sound with the name "Funk".
    public static let funk = NSSound(named: .funk)
    /// The sound with the name "Glass".
    public static let glass = NSSound(named: .glass)
    /// The sound with the name "Hero".
    public static let hero = NSSound(named: .hero)
    /// The sound with the name "Morse".
    public static let morse = NSSound(named: .morse)
    /// The sound with the name "Ping".
    public static let ping = NSSound(named: .ping)
    /// The sound with the name "Pop".
    public static let pop = NSSound(named: .pop)
    /// The sound with the name "Purr".
    public static let purr = NSSound(named: .purr)
    /// The sound with the name "Sosumi".
    public static let sosumi = NSSound(named: .sosumi)
    /// The sound with the name "Submarine".
    public static let submarine = NSSound(named: .submarine)
    /// The sound with the name "Tink".
    public static let tink = NSSound(named: .tink)
}

extension NSSound {
    /// Returns the `NSSound` instance associated with a given name.
    internal convenience init?(named name: FrameworkToolbox<NSSound>.SoundName) {
        self.init(named: name.rawValue)
    }
}

#endif
