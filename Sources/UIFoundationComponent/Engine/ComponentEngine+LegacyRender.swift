extension ComponentEngine {
    func performLegacyRender(
        hostingView: NSUIView,
        newVisibleRenderables: [Renderable],
        shouldUpdateViews: Bool
    ) -> [NSUIView] {
        var newIndexByIdentifier = [String: Int]()
        newIndexByIdentifier.reserveCapacity(newVisibleRenderables.count)
        for (index, renderable) in newVisibleRenderables.enumerated() {
            newIndexByIdentifier[renderable.id] = index
        }

        var newViews = [NSUIView?](repeating: nil, count: newVisibleRenderables.count)

        // 1st pass: delete removed cells and carry over reusable existing cells.
        for index in 0..<visibleViews.count {
            let oldRenderable = visibleRenderables[index]
            let oldView = visibleViews[index]
            if let newIndex = newIndexByIdentifier[oldRenderable.id] {
                newViews[newIndex] = oldView
            } else {
                let viewAnimator = oldRenderable.renderNode.animator ?? animator
                viewAnimator.shift(hostingView: hostingView, delta: contentOffsetDelta, view: oldView)
                viewAnimator.delete(hostingView: hostingView, view: oldView) {
                    oldView.recycleForComponentReuse()
                }
            }
        }

        // 2nd pass: create missing cells, update frames, and restore subview order.
        let containerView = contentView ?? hostingView
        for (index, renderable) in newVisibleRenderables.enumerated() {
            let viewAnimator = renderable.renderNode.animator ?? animator
            let frame = renderable.frame
            let cell: NSUIView
            if let existingView = newViews[index] {
                cell = existingView
                if shouldUpdateViews {
                    renderable.renderNode._updateView(cell)
                    viewAnimator.shift(hostingView: hostingView, delta: contentOffsetDelta, view: cell)
                }
            } else {
                cell = renderable.renderNode._makeView()
                NSUIView.box.performWithoutAnimation {
                    cell.box.setFrame(frame)
                    cell.box.layoutIfNeeded()
                    renderable.renderNode._updateView(cell)
                }
                viewAnimator.insert(hostingView: hostingView, view: cell, frame: frame)
                newViews[index] = cell
            }
            viewAnimator.update(hostingView: hostingView, view: cell, frame: frame)
            containerView.box.insertSubview(cell, at: index)
        }

        return newViews as! [NSUIView]
    }
}
