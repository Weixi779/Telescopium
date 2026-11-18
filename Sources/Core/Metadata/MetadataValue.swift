//
//  MetadataValue.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation

public typealias Metadata = [String: MetadataValue]

/// A typed field carried by telemetry records.
public enum MetadataValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case bytes(Data)
    case array([MetadataValue])
    case object(Metadata)
}

extension MetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension MetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .int(value)
    }
}

extension MetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension MetadataValue: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension MetadataValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: MetadataValue...) {
        self = .array(elements)
    }
}

extension MetadataValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, MetadataValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}
