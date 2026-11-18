//
//  SpanId.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// A nonzero 64-bit span identifier, encoded as 16 lowercase hexadecimal digits.
public struct SpanId: Sendable, Hashable, Codable {
    private let value: UInt64

    public init?(hexString: String) {
        guard let value = HexEncoding.decode(hexString, width: 16), value != 0 else {
            return nil
        }
        self.init(value: value)
    }

    private init(value: UInt64) {
        self.value = value
    }

    public var hexString: String {
        HexEncoding.encode(value, width: 16)
    }

    public static func random() -> SpanId {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// Consumes one generator output per attempt; retries zero values.
    public static func random<R: RandomNumberGenerator>(using generator: inout R) -> SpanId {
        while true {
            let value = generator.next()
            if value != 0 {
                return SpanId(value: value)
            }
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = SpanId(hexString: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid W3C span-id.")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
