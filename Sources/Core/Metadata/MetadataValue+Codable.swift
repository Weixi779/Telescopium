//
//  MetadataValue+Codable.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Each node carries its type tag, including values inside arrays and objects.
extension MetadataValue: Codable {
    private enum Tag: String, CodingKey {
        case null, bool, int, double, string, bytes, array, object
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Tag.self)
        switch self {
        case .null:
            try container.encodeNil(forKey: .null)
        case .bool(let value):
            try container.encode(value, forKey: .bool)
        case .int(let value):
            try container.encode(value, forKey: .int)
        case .double(let value):
            if value.isNaN {
                try container.encode("NaN", forKey: .double)
            } else if value.isInfinite {
                try container.encode(value.sign == .minus ? "-Infinity" : "Infinity", forKey: .double)
            } else {
                try container.encode(value, forKey: .double)
            }
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .bytes(let value):
            try container.encode(value.base64EncodedString(), forKey: .bytes)
        case .array(let values):
            try container.encode(values, forKey: .array)
        case .object(let fields):
            try container.encode(fields, forKey: .object)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Tag.self)
        let keys = container.allKeys
        guard keys.count == 1, let tag = keys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Expected one metadata value tag.")
            )
        }

        switch tag {
        case .null:
            guard try container.decodeNil(forKey: tag) else {
                throw DecodingError.dataCorruptedError(forKey: tag, in: container, debugDescription: "Expected null.")
            }
            self = .null
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: tag))
        case .int:
            self = .int(try container.decode(Int64.self, forKey: tag))
        case .double:
            if let spelling = try? container.decode(String.self, forKey: tag) {
                switch spelling {
                case "NaN": self = .double(.nan)
                case "Infinity": self = .double(.infinity)
                case "-Infinity": self = .double(-.infinity)
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: tag,
                        in: container,
                        debugDescription: "Unknown nonfinite double spelling."
                    )
                }
            } else {
                self = .double(try container.decode(Double.self, forKey: tag))
            }
        case .string:
            self = .string(try container.decode(String.self, forKey: tag))
        case .bytes:
            let text = try container.decode(String.self, forKey: tag)
            guard let data = Data(base64Encoded: text) else {
                throw DecodingError.dataCorruptedError(forKey: tag, in: container, debugDescription: "Invalid Base64.")
            }
            self = .bytes(data)
        case .array:
            self = .array(try container.decode([MetadataValue].self, forKey: tag))
        case .object:
            self = .object(try container.decode(Metadata.self, forKey: tag))
        }
    }
}
