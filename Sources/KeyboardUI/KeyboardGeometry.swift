import CoreGraphics

enum KeyboardGeometry {
    /// A horizontal division separates a reading panel above a typing panel.
    /// Vertical book folds and small multitasking windows keep their usual layout.
    static func tabletopHeight(in bounds: CGRect, divisions: [CGRect]) -> CGFloat? {
        guard bounds.width >= 650 else { return nil }
        return divisions.compactMap { region -> CGFloat? in
            guard region.width >= bounds.width * 0.8, region.width > region.height,
                  region.minY > bounds.minY + bounds.height * 0.25,
                  region.maxY < bounds.minY + bounds.height * 0.7 else { return nil }
            let height = bounds.maxY - region.maxY
            return height >= 260 ? height : nil
        }.min()
    }

    static func horizontalSegments(in rect: CGRect, excluding regions: [CGRect]) -> [CGRect] {
        regions.reduce([rect]) { segments, region in
            segments.flatMap { segment -> [CGRect] in
                guard segment.intersects(region) else { return [segment] }
                return [
                    CGRect(x: segment.minX, y: segment.minY, width: max(0, region.minX - segment.minX), height: segment.height),
                    CGRect(x: region.maxX, y: segment.minY, width: max(0, segment.maxX - region.maxX), height: segment.height)
                ].filter { $0.width > 24 }
            }
        }
    }
}
