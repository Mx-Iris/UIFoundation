//
// ChatLayout
// KeyboardListenerDelegate.swift
// https://github.com/ekazaev/ChatLayout
//
// Created by Eugene Kazaev in 2020-2024.
// Distributed under the MIT license.
//
// Become a sponsor:
// https://github.com/sponsors/ekazaev
//

#if os(iOS)

import Foundation

public protocol KeyboardListenerDelegate: AnyObject {
    func keyboardWillShow(info: KeyboardInfo)
    func keyboardDidShow(info: KeyboardInfo)
    func keyboardWillHide(info: KeyboardInfo)
    func keyboardDidHide(info: KeyboardInfo)
    func keyboardWillChangeFrame(info: KeyboardInfo)
    func keyboardDidChangeFrame(info: KeyboardInfo)
}

extension KeyboardListenerDelegate {
    public func keyboardWillShow(info: KeyboardInfo) {}
    public func keyboardDidShow(info: KeyboardInfo) {}
    public func keyboardWillHide(info: KeyboardInfo) {}
    public func keyboardDidHide(info: KeyboardInfo) {}
    public func keyboardWillChangeFrame(info: KeyboardInfo) {}
    public func keyboardDidChangeFrame(info: KeyboardInfo) {}
}


#endif
