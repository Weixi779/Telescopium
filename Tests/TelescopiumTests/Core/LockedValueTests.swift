//
//  LockedValueTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/19.
//  Copyright © 2026 Telescopium.
//

import Testing
@testable import Telescopium

struct LockedValueTests {
    @Test("Concurrent callers each observe a distinct increment")
    func concurrentMutation() async {
        let counter = LockedValue(0)
        let count = 64
        let observed = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<count {
                group.addTask {
                    counter.withLock { value in
                        value += 1
                        return value
                    }
                }
            }

            var values: Set<Int> = []
            for await value in group {
                values.insert(value)
            }
            return values
        }

        #expect(observed == Set(1...count))
    }
}
