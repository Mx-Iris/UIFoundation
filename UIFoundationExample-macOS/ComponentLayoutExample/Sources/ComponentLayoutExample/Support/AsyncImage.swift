//
//  AsyncImage.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/5/25), with the image loading rewritten.
//
//  Upstream reaches for Kingfisher. This version uses `URLSession` and an
//  `NSCache` instead, so the example adds no third-party dependency for the
//  sake of six sample photos -- and so it degrades to a placeholder tint when
//  the machine is offline rather than showing nothing at all.
//

import AppKit
import UIFoundationComponent

/// Sample photos with known aspect ratios, which is what lets the waterfall
/// chapter lay them out before any of them has loaded.
public struct ImageData {
    public let url: URL
    public let size: CGSize

    public init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
    }

    public static let sample: [ImageData] = [
        ImageData(url: URL(string: "https://unsplash.com/photos/Yn0l7uwBrpw/download?force=true&w=640")!, size: CGSize(width: 640, height: 360)),
        ImageData(url: URL(string: "https://unsplash.com/photos/J4-xolC4CCU/download?force=true&w=640")!, size: CGSize(width: 640, height: 800)),
        ImageData(url: URL(string: "https://unsplash.com/photos/biggKnv1Oag/download?force=true&w=640")!, size: CGSize(width: 640, height: 434)),
        ImageData(url: URL(string: "https://unsplash.com/photos/MR2A97jFDAs/download?force=true&w=640")!, size: CGSize(width: 640, height: 959)),
        ImageData(url: URL(string: "https://unsplash.com/photos/oaCnDk89aho/download?force=true&w=640")!, size: CGSize(width: 640, height: 426)),
        ImageData(url: URL(string: "https://unsplash.com/photos/MOfETox0bkE/download?force=true&w=640")!, size: CGSize(width: 640, height: 426)),
    ]
}

/// An image view that fills itself from a URL.
public final class AsyncImageView: NSImageView {
    private static let cache = NSCache<NSURL, NSImage>()

    /// Tracks which URL the in-flight load belongs to, so a recycled view does
    /// not end up showing the picture requested by whoever had it last.
    private var loadingURL: URL?

    public var url: URL? {
        didSet {
            guard url != oldValue else { return }
            load()
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemGray5.cgColor
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func load() {
        image = nil
        loadingURL = url
        guard let url else { return }

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let loaded = NSImage(data: data) else { return }
            Self.cache.setObject(loaded, forKey: url as NSURL)
            DispatchQueue.main.async {
                // The view may have been recycled onto a different row while
                // this was in flight.
                guard let self, self.loadingURL == url else { return }
                self.image = loaded
            }
        }.resume()
    }
}

/// Displays a remote image, sized by the layout system rather than by the image.
public struct AsyncImage: ComponentBuilder {
    let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public func build() -> some Component {
        ViewComponent<AsyncImageView>().url(url)
    }
}
