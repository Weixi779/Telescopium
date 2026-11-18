//
//  MetadataValue+Conversion.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import CoreFoundation
import Foundation
#if DEBUG
import os
#endif

extension Metadata {
    /// Converts dynamic fields, keeping supported members and array elements.
    public init(converting fields: [String: Any]) {
        self.init(minimumCapacity: fields.count)
        var converter = MetadataValueConverter()
        for (key, value) in fields {
            self[key] = converter.convert(value, at: "metadata[\(key.debugDescription)]")
        }
    }
}

extension MetadataValue {
    /// Returns nil for unsupported values. Arrays and objects retain their supported children.
    public init?(converting value: Any) {
        var converter = MetadataValueConverter()
        guard let result = converter.convert(value, at: "value") else { return nil }
        self = result
    }
}

private struct MetadataValueConverter {
    #if DEBUG
    private static let diagnostics = os.Logger(subsystem: "Telescopium", category: "Metadata")
    #endif

    // Foundation containers can refer back to themselves.
    private var ancestors: Set<ObjectIdentifier> = []

    mutating func convert(_ value: Any, at path: @autoclosure () -> String) -> MetadataValue? {
        if let typed = value as? MetadataValue { return typed }
        let object = value as AnyObject
        switch object {
        case is NSNull:
            return .null
        case let text as NSString:
            return .string(text as String)
        case let data as NSData:
            return .bytes(data as Data)
        case let number as NSNumber:
            if let field = Self.convert(number) { return field }
        case let array as NSArray:
            let id = ObjectIdentifier(array)
            guard ancestors.insert(id).inserted else { break }
            defer { ancestors.remove(id) }
            return .array((0..<array.count).compactMap { index in
                convert(array[index], at: "\(path())[\(index)]")
            })
        case let dictionary as NSDictionary:
            let id = ObjectIdentifier(dictionary)
            guard ancestors.insert(id).inserted else { break }
            defer { ancestors.remove(id) }
            var fields = Metadata(minimumCapacity: dictionary.count)
            for (key, item) in dictionary {
                guard let key = key as? String else {
                    #if DEBUG
                    let location = path()
                    Self.diagnostics.debug("Skipped non-string key in \(location, privacy: .public)")
                    #endif
                    continue
                }
                fields[key] = convert(item, at: "\(path())[\(key.debugDescription)]")
            }
            return .object(fields)
        default:
            break
        }

        #if DEBUG
        let location = path()
        let typeName = String(reflecting: type(of: value))
        Self.diagnostics.debug("Skipped unsupported metadata at \(location, privacy: .public) (\(typeName, privacy: .public))")
        #endif
        return nil
    }

    private static func convert(_ number: NSNumber) -> MetadataValue? {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
        // A decimal may carry more precision than the metadata double can represent.
        if number is NSDecimalNumber { return nil }
        switch String(cString: number.objCType) {
        case "c", "s", "i", "l", "q":
            return .int(number.int64Value)
        case "C", "S", "I", "L", "Q":
            return Int64(exactly: number.uint64Value).map(MetadataValue.int)
        case "f", "d":
            return .double(number.doubleValue)
        default:
            return nil
        }
    }
}
