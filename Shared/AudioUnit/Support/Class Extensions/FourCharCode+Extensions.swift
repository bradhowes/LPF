// Copyright © 2020 Brad Howes. All rights reserved.

import Foundation

extension FourCharCode {

    private static let bytesSizeForStringValue = MemoryLayout<Self>.size

    /// Obtain a 4-character string from our value - based on https://stackoverflow.com/a/60367676/629836
    public var stringValue: String {
        withUnsafePointer(to: bigEndian) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: Self.bytesSizeForStringValue) { bytes in
                String(bytes: UnsafeBufferPointer(start: bytes, count: Self.bytesSizeForStringValue),
                       encoding: .macOSRoman) ?? "????"
            }
        }
    }
}
