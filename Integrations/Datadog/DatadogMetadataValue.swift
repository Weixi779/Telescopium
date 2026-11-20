//
//  DatadogMetadataValue.swift
//  TelescopiumDatadog
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

#if Datadog
import Telescopium

/// Encodes the JSON value a Datadog user can query at this attribute's key.
struct DatadogMetadataValue: Encodable {
    let value: MetadataValue

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value) where value.isNaN: try container.encode("NaN")
        case let .double(value) where value.isInfinite:
            try container.encode(value.sign == .minus ? "-Infinity" : "Infinity")
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .bytes(value): try container.encode(value.base64EncodedString())
        case let .array(values): try container.encode(values.map(DatadogMetadataValue.init))
        case let .object(fields): try container.encode(fields.mapValues(DatadogMetadataValue.init))
        }
    }
}
#endif
