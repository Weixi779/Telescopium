//
//  TraceParent.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// A W3C Trace Context version 00 propagation value.
/// Format: https://www.w3.org/TR/trace-context/#traceparent-header-field-values
///
/// `spanId` is the sender's current span, serialized as the wire format's `parent-id`.
/// This value does not own span lifecycles, sampling decisions, or context propagation.
public struct TraceParent: Sendable, Hashable, Codable {
    public let traceId: TraceId
    public let spanId: SpanId
    /// Raw trace flags. Preserved verbatim; interpreting them belongs to the caller.
    public let flags: UInt8

    public init(traceId: TraceId, spanId: SpanId, flags: UInt8) {
        self.traceId = traceId
        self.spanId = spanId
        self.flags = flags
    }

    /// Accepts exactly the lowercase, 55-byte version 00 format, without whitespace.
    /// Unsupported versions and invalid identifiers return nil.
    public init?(headerValue: String) {
        guard headerValue.utf8.count == 55 else { return nil }
        let fields = headerValue.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 4,
              fields[0] == "00",
              let traceId = TraceId(hexString: String(fields[1])),
              let spanId = SpanId(hexString: String(fields[2])),
              let flags = HexEncoding.decode(String(fields[3]), width: 2) else {
            return nil
        }
        self.init(traceId: traceId, spanId: spanId, flags: UInt8(flags))
    }

    public var headerValue: String {
        "00-\(traceId.hexString)-\(spanId.hexString)-\(HexEncoding.encode(UInt64(flags), width: 2))"
    }

    /// Generates independent identifiers with flags set to 00 using the system random source.
    public static func random() -> TraceParent {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// Generates the trace identifier first, then the span identifier, with flags set to 00.
    public static func random<R: RandomNumberGenerator>(using generator: inout R) -> TraceParent {
        let traceId = TraceId.random(using: &generator)
        let spanId = SpanId.random(using: &generator)
        return TraceParent(traceId: traceId, spanId: spanId, flags: 0)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = TraceParent(headerValue: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid W3C version 00 traceparent.")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(headerValue)
    }
}
