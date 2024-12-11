//
// ChatLayout
// KeyboardInfo.swift
// https://github.com/ekazaev/ChatLayout
//
// Created by Eugene Kazaev in 2020-2024.
// Distributed under the MIT license.
//
// Become a sponsor:
// https://github.com/sponsors/ekazaev
//

#if canImport(UIKit)

import UIKit

public struct KeyboardInfo: Equatable {
    public let animationDuration: Double

    public let animationCurve: UIView.AnimationCurve

    public let frameBegin: CGRect

    public let frameEnd: CGRect

    public let isLocal: Bool

    public var targetResponder: UIResponder?
    
    init?(_ notification: Notification) {
        guard let userInfo: NSDictionary = notification.userInfo as NSDictionary?,
              let keyboardAnimationCurve = (userInfo.object(forKey: UIResponder.keyboardAnimationCurveUserInfoKey) as? NSValue) as? Int,
              let keyboardAnimationDuration = (userInfo.object(forKey: UIResponder.keyboardAnimationDurationUserInfoKey) as? NSValue) as? Double,
              let keyboardIsLocal = (userInfo.object(forKey: UIResponder.keyboardIsLocalUserInfoKey) as? NSValue) as? Bool,
              let keyboardFrameBegin = (userInfo.object(forKey: UIResponder.keyboardFrameBeginUserInfoKey) as? NSValue)?.cgRectValue,
              let keyboardFrameEnd = (userInfo.object(forKey: UIResponder.keyboardFrameEndUserInfoKey) as? NSValue)?.cgRectValue else {
            return nil
        }

        animationDuration = keyboardAnimationDuration
        var animationCurve = UIView.AnimationCurve.easeInOut
        NSNumber(value: keyboardAnimationCurve).getValue(&animationCurve)
        self.animationCurve = animationCurve
        isLocal = keyboardIsLocal
        frameBegin = keyboardFrameBegin
        frameEnd = keyboardFrameEnd
    }
}


#endif
