#if NSAttributedStringBuilder

import Foundation

public typealias ATextGroup = NSAttributedString.AttrTextGroup

extension NSAttributedString {
    public struct AttrTextGroup: Component {
        public let string: String = ""

        public let attributes: Attributes = [:]

        private var attributedTexts: [AText]

        private var components: [Component]

        public var attributedString: NSAttributedString {
            let mutableAttributedString = NSMutableAttributedString(string: "")
            for component in components {
                mutableAttributedString.append(component.attributedString)
            }
            return mutableAttributedString
        }

        public init(@AttrTextGroupBuilder attrTextGroupBuilder: () -> [Component]) {
            self.init(components: attrTextGroupBuilder())
        }

        private init(components: [Component]) {
            self.components = components
            self.attributedTexts = components.compactMap { $0 as? AText }
        }

        public func attributes(_ newAttributes: Attributes) -> Component {
            guard attributedTexts.count > 0 else { return self }
            var resolvedComponents = [Component]()
            for attribute in newAttributes {
                resolvedComponents.append(contentsOf: setAttributed(with: attribute, to: components))
            }
            return AttrTextGroup(components: resolvedComponents)
        }

        private func setAttributed(with newAttribute: (key: NSAttributedString.Key, value: Any), to components: [Component]) -> [Component] {
            var resolvedComponents = [Component]()
            for component in components {
                if let attributedText = component as? AText {
                    let resolvedString = attributedText.string
                    var resolvedAttributes = attributedText.attributes
                    resolvedAttributes[newAttribute.key] = newAttribute.value
                    resolvedComponents.append(AText(resolvedString, attributes: resolvedAttributes))
                } else if let group = component as? AttrTextGroup {
                    resolvedComponents.append(contentsOf: setAttributed(with: newAttribute, to: group.components))
                } else {
                    resolvedComponents.append(component)
                }
            }
            return resolvedComponents
        }
    }
}

@resultBuilder
public enum AttrTextGroupBuilder {
    public static func buildBlock(_ components: Component...) -> [Component] {
        components.map { $0 }
    }
}

#endif
