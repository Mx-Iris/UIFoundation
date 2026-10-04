#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSSpellChecker` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// None has properties. AppKit implements all eight through one internal protocol,
// `StandardNSSpellCheckerMessage`, reproduced here under AppKit's name: converting a notification never
// fails, and making one posts it from `NSSpellChecker.shared`.

extension NSSpellChecker {
    /// Backports of the messages AppKit declares on `NSSpellChecker` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

protocol StandardNSSpellCheckerMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSSpellChecker {
    init()
}

extension StandardNSSpellCheckerMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: NSSpellChecker.shared, userInfo: nil)
    }
}

extension NSSpellChecker.Backport {
    /// A message that the spell checker sends when the automatic spelling correction setting changes.
    public struct DidChangeAutomaticSpellingCorrectionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticSpellingCorrectionNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic text replacement setting changes.
    public struct DidChangeAutomaticTextReplacementMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticTextReplacementNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic quote substitution setting changes.
    public struct DidChangeAutomaticQuoteSubstitutionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticQuoteSubstitutionNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic dash substitution setting changes.
    public struct DidChangeAutomaticDashSubstitutionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticDashSubstitutionNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic capitalization setting changes.
    public struct DidChangeAutomaticCapitalizationMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticCapitalizationNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic period substitution setting changes.
    public struct DidChangeAutomaticPeriodSubstitutionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticPeriodSubstitutionNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic text completion setting changes.
    public struct DidChangeAutomaticTextCompletionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            NSSpellChecker.didChangeAutomaticTextCompletionNotification
        }

        public init() {}
    }

    /// A message that the spell checker sends when the automatic inline prediction setting changes.
    @available(macOS 14.0, *)
    public struct DidChangeAutomaticInlinePredictionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSSpellCheckerMessage {
        public typealias Subject = NSSpellChecker

        public static var name: Notification.Name {
            .NSSpellCheckerDidChangeAutomaticInlinePrediction
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticSpellingCorrectionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticSpellingCorrectionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticSpellingCorrection: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticTextReplacementMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticTextReplacementMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticTextReplacement: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticQuoteSubstitutionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticQuoteSubstitutionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticQuoteSubstitution: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticDashSubstitutionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticDashSubstitutionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticDashSubstitution: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticCapitalizationMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticCapitalizationMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticCapitalization: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticPeriodSubstitutionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticPeriodSubstitutionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticPeriodSubstitution: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticTextCompletionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticTextCompletionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticTextCompletion: Self { .init() }
}

@available(macOS 14.0, *)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSpellChecker.Backport.DidChangeAutomaticInlinePredictionMessage> {
    /// The identifier of `NSSpellChecker.Backport.DidChangeAutomaticInlinePredictionMessage`.
    @_disfavoredOverload
    public static var didChangeAutomaticInlinePrediction: Self { .init() }
}

#endif
