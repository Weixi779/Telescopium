//
//  TraceId.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// A nonzero 128-bit trace identifier, encoded as 32 lowercase hexadecimal digits.
public struct TraceId: Sendable, Hashable, Codable {
    private let high: UInt64
    private let low: UInt64

    public init?(hexString: String) {
        guard hexString.utf8.count == 32 else { return nil }
        let digits = Array(hexString.utf8)
        guard let high = HexEncoding.decode(String(decoding: digits[..<16], as: UTF8.self), width: 16),
              let low = HexEncoding.decode(String(decoding: digits[16...], as: UTF8.self), width: 16),
              high != 0 || low != 0 else {
            return nil
        }
        self.init(high: high, low: low)
    }

    private init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    public var hexString: String {
        HexEncoding.encode(high, width: 16) + HexEncoding.encode(low, width: 16)
    }

    public static func random() -> TraceId {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// Consumes two generator outputs per attempt, high word first; retries all-zero values.
    public static func random<R: RandomNumberGenerator>(using generator: inout R) -> TraceId {
        while true {
            let high = generator.next()
            let low = generator.next()
            if high != 0 || low != 0 {
                return TraceId(high: high, low: low)
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = TraceId(hexString: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid W3C trace-id.")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
