#if FilterUI

import AppKit

/// Used internally by ``FilterTokenFieldCell`` to perform attachment cell replacement as the tokens are inserted in the field editor.
@objc open class FilterTokenTextStorage: NSTextStorage {
    open weak var tokenDelegate: FilterTokenTextStorageDelegate?
    public let storage: NSTextStorage

    public init(textStorage: NSTextStorage) {
        storage = NSTextStorage(string: textStorage.string, attributes: nil)
        super.init()
    }

    public override init() {
        storage = NSTextStorage(string: "", attributes: nil)
        super.init()
    }

    public override init(attributedString attrStr: NSAttributedString) {
        storage = NSTextStorage(attributedString: attrStr)
        super.init(attributedString: attrStr)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    open override var string: String { storage.string }

    open override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        storage.attributes(at: location, effectiveRange: range)
    }

    open override func replaceCharacters(in range: NSRange, with str: String) {
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
    }

    open override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        storage.setAttributes(attrs, range: range)
        if let attachment = attrs?[.attachment] as? NSTextAttachment {
            tokenDelegate?.tokenTextStorage?(self, updateTokenAttachment: attachment, forRange: range)
        }
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    open override func removeAttribute(_ name: NSAttributedString.Key, range: NSRange) {
        storage.removeAttribute(name, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
    }

    open override func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        storage.replaceCharacters(in: range, with: attrString)

        let strRange = NSMakeRange(range.location, attrString.length)
        storage.enumerateAttribute(.attachment, in: strRange) { [self] attachment, range, _ in
            if let attachment = attachment as? NSTextAttachment {
                tokenDelegate?.tokenTextStorage?(self, updateTokenAttachment: attachment, forRange: range)
            }
        }

        edited([.editedAttributes, .editedCharacters], range: range, changeInLength: strRange.length - range.length)
    }
}

@objc public protocol FilterTokenTextStorageDelegate: NSObjectProtocol {
    @objc optional func tokenTextStorage(_ textStorage: FilterTokenTextStorage, updateTokenAttachment attachment: NSTextAttachment, forRange range: NSRange)
}

// #pragma mark - Primitive Methods
//
// - (NSString *)string
// {
//    return [_string string];
// }
//
// - (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
// {
//    return [_string attributesAtIndex:location effectiveRange:range];
// }
//
// - (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
// {
//    [_string replaceCharactersInRange:range withString:str];
//    [self edited:NSTextStorageEditedCharacters range:range changeInLength:str.length - range.length];
// }
//
// - (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
// {
//    [_string setAttributes:attrs range:range];
//    NSTextAttachment *attachment = attrs[NSAttachmentAttributeName];
//    if ( attachment && [self.delegate respondsToSelector:@selector(tokenTextStorage:updateTokenAttachment:forRange:)] )
//        [self.delegate tokenTextStorage:self updateTokenAttachment:attachment forRange:range];
//    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
// }
//
// #pragma mark - Convenience Methods
//
// - (void)removeAttribute:(NSString *)name range:(NSRange)range
// {
//    [_string removeAttribute:name range:range];
//    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
// }
//
// - (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString
// {
//    [_string replaceCharactersInRange:range withAttributedString:attrString];
//    NSRange strRange = NSMakeRange(range.location, attrString.length);
//
//    [_string enumerateAttribute:NSAttachmentAttributeName inRange:strRange options:0 usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop) {
//        if ( attachment && [self.delegate respondsToSelector:@selector(tokenTextStorage:updateTokenAttachment:forRange:)] ) {
//            [self.delegate tokenTextStorage:self updateTokenAttachment:attachment forRange:range];
//        }
//    }];
//    [self edited:NSTextStorageEditedAttributes | NSTextStorageEditedCharacters range:range changeInLength:strRange.length - range.length];
// }

#endif
