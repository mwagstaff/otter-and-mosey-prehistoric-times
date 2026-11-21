import CoreGraphics

/// Top-left coordinates in the 900 × 600 camp painting. The tent, fire and tool bench
/// border the clearing. Navigation and drops use the same painting coordinates.
struct CampGround: Equatable {
    let scale: CGFloat
    let offset: CGPoint
    let viewport: CGRect
    let decorationBases: [CGRect]

    init(paintingFrame: CGRect, viewport: CGRect, decorations: [CGPoint], propSize: CGFloat) {
        scale = max(paintingFrame.width / 900, paintingFrame.height / 600, 0.001)
        offset = CGPoint(x: paintingFrame.midX - 450 * scale, y: paintingFrame.midY - 300 * scale)
        self.viewport = viewport.offsetBy(dx: -offset.x, dy: -offset.y)
            .applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        let side = propSize / scale
        // A prop occupies the dirt under its base. The transparent corners, foliage
        // and the pearl above the fountain are not barriers across the clearing.
        decorationBases = decorations.map { [scale, offset] point in
            CGRect(x: (point.x - offset.x) / scale - side * 0.32,
                   y: (point.y - offset.y) / scale + side * 0.19,
                   width: side * 0.64, height: side * 0.27)
        }
    }

    func painting(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.x) / scale, y: (point.y - offset.y) / scale)
    }
    func screen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
    }

    /// The dirt extends below both the fire and the bench, then narrows into a
    /// path between the foreground plants. Coordinates follow the painting.
    func walkingArea(width: CGFloat, height: CGFloat) -> CampWalkingArea {
        let scenery = [
            CGRect(x: 0, y: 300, width: 147, height: 155),     // tent and stools
            CGRect(x: 145, y: 350, width: 108, height: 98),   // fire ring
            CGRect(x: 239, y: 385, width: 47, height: 48),    // stump
            CGRect(x: 683, y: 315, width: 217, height: 129),  // workbench
            CGRect(x: 781, y: 427, width: 119, height: 39),   // crate and rope
            CGRect(x: 0, y: 450, width: 125, height: 150),
            CGRect(x: 0, y: 476, width: 149, height: 124),
            CGRect(x: 0, y: 501, width: 232, height: 99),
            CGRect(x: 0, y: 523, width: 390, height: 77),
            CGRect(x: 0, y: 557, width: 476, height: 43),
            CGRect(x: 813, y: 475, width: 87, height: 125),
            CGRect(x: 752, y: 505, width: 148, height: 95),
            CGRect(x: 666, y: 516, width: 234, height: 84),
            CGRect(x: 622, y: 547, width: 278, height: 53)
        ]
        let visible = viewport.insetBy(dx: width / 2, dy: height / 2)
        let dirt = CGRect(x: 0, y: 431 - height * 0.42, width: 900, height: 158)
        let fixedBlocks = scenery.map {
            $0.insetBy(dx: -width / 2 - 2, dy: -height / 2 - 2)
        }
        // Routes use sprite centres, but collision happens at the feet. Project
        // the expanded base back into those centre coordinates.
        let props = decorationBases.map {
            $0.insetBy(dx: -width * 0.30 - 2, dy: -height * 0.09 - 2)
                .offsetBy(dx: 0, dy: -height * 0.38)
        }
        return CampWalkingArea(bounds: visible.intersection(dirt), blocks: fixedBlocks + props)
    }
}

struct CampWalkingArea {
    let bounds: CGRect
    let blocks: [CGRect]

    func contains(_ p: CGPoint) -> Bool {
        !bounds.isNull && p.x >= bounds.minX && p.x <= bounds.maxX &&
        p.y >= bounds.minY && p.y <= bounds.maxY && !blocks.contains { $0.contains(p) }
    }

    func nearest(_ p: CGPoint) -> CGPoint? {
        guard !bounds.isNull else { return nil }
        if contains(p) { return p }
        let x = min(bounds.maxX, max(bounds.minX, p.x))
        let y = min(bounds.maxY, max(bounds.minY, p.y))
        var best: CGPoint?
        var distance = CGFloat.infinity
        // The nearest legal centre is on the viewport or an expanded obstacle edge.
        let rows = [y, bounds.minY, bounds.maxY] + blocks.flatMap { [$0.minY - 0.5, $0.maxY + 0.5] }
        for row in rows where row >= bounds.minY && row <= bounds.maxY {
            let across = blocks.filter { $0.minY <= row && row <= $0.maxY }
            let columns = [x, bounds.minX, bounds.maxX] + across.flatMap { [$0.minX - 0.5, $0.maxX + 0.5] }
            for col in columns {
                let candidate = CGPoint(x: col, y: row)
                let d = hypot(col - p.x, row - p.y)
                if d < distance && contains(candidate) { best = candidate; distance = d }
            }
        }
        return best
    }

    /// Slab intersection checks the entire segment, even for a thin prop.
    func clear(from a: CGPoint, to b: CGPoint) -> Bool {
        guard contains(a), contains(b) else { return false }
        return !blocks.contains { rect in
            var enter: CGFloat = 0, leave: CGFloat = 1
            func overlaps(_ start: CGFloat, _ delta: CGFloat, _ low: CGFloat, _ high: CGFloat) -> Bool {
                if abs(delta) < 0.0001 { return start >= low && start <= high }
                let t0 = (low - start) / delta, t1 = (high - start) / delta
                enter = max(enter, min(t0, t1))
                leave = min(leave, max(t0, t1))
                return enter <= leave
            }
            return overlaps(a.x, b.x - a.x, rect.minX, rect.maxX) &&
                overlaps(a.y, b.y - a.y, rect.minY, rect.maxY)
        }
    }

    /// Connect visible corners only when a straight walk is obstructed.
    func route(from start: CGPoint, to end: CGPoint) -> CampWalk? {
        if clear(from: start, to: end) { return CampWalk(points: [start, end]) }
        guard contains(start), contains(end) else { return nil }
        var points = [start, end]
        for rect in blocks where bounds.intersects(rect) {
            for x in [rect.minX - 1, rect.maxX + 1] {
                for y in [rect.minY - 1, rect.maxY + 1] {
                    let corner = CGPoint(x: x, y: y)
                    if contains(corner) { points.append(corner) }
                }
            }
        }
        var costs = Array(repeating: CGFloat.infinity, count: points.count)
        var previous = Array(repeating: -1, count: points.count)
        var open = Set(points.indices)
        costs[0] = 0
        while let i = open.min(by: { costs[$0] < costs[$1] }), costs[i].isFinite {
            if i == 1 {
                var path = [end], j = i
                while j != 0 { j = previous[j]; path.append(points[j]) }
                return CampWalk(points: path.reversed())
            }
            open.remove(i)
            for j in open {
                let d = costs[i] + hypot(points[j].x - points[i].x, points[j].y - points[i].y)
                if d < costs[j] && clear(from: points[i], to: points[j]) {
                    costs[j] = d
                    previous[j] = i
                }
            }
        }
        return nil
    }
}

struct CampWalk {
    let points: [CGPoint]
    var length: CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }
    func sample(_ distance: CGFloat) -> (point: CGPoint, west: Bool) {
        var remaining = max(0, distance)
        for (a, b) in zip(points, points.dropFirst()) {
            let dx = b.x - a.x, dy = b.y - a.y, length = hypot(dx, dy)
            if remaining <= length && length > 0 {
                return (CGPoint(x: a.x + dx * remaining / length, y: a.y + dy * remaining / length), dx < 0)
            }
            remaining -= length
        }
        let last = points[points.count - 1]
        return (last, last.x < points[points.count - 2].x)
    }
}
