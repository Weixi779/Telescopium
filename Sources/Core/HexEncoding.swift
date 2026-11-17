//
//  HexEncoding.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// Fixed-width lowercase hexadecimal encoding used by the W3C wire format.
enum HexEncoding {
    static func decode(_ string: String, width: Int) -> UInt64? {
        guard string.utf8.count == width,
              string.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            return nil
        }
        return UInt64(string, radix: 16)
    }

    static func encode(_ value: UInt64, width: Int) -> String {
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: width - digits.count) + digits
    }
}
