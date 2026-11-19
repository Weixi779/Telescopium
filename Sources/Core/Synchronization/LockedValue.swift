//
//  LockedValue.swift
//  Telescopium
//
//  Created by weixi on 2026/11/19.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Provides exclusive access to a value for the duration of a synchronous closure.
final class LockedValue<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try lock.withLock { try body(&value) }
    }
}

// All access to the stored value is synchronized by the same lock.
extension LockedValue: @unchecked Sendable where Value: Sendable {}
