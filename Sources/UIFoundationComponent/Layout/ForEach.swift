//  Created by Luke Zhao on 8/23/20.

@available(*, deprecated, message: "Please use for-in loop instead")
public struct ForEach<DataSequence: Sequence, DataElement>: ComponentArrayContainer where DataSequence.Element == DataElement {
    public let components: [any Component]

    public init(_ data: DataSequence, @ComponentArrayBuilder _ content: (DataElement) -> [any Component]) {
        components = data.flatMap { content($0) }
    }
}
