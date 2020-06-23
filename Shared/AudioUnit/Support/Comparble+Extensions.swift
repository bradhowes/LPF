// Copyright © 2020 Apple. All rights reserved.

public extension Comparable {
    func clamp(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
