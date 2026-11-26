//
//  CapturingSpanExporter.swift
//  Telescopium
//
//  Created by weixi on 2026/11/26.
//  Copyright © 2026 Telescopium.
//

@testable import Telescopium

struct CapturingSpanExporter: SpanExporter {
    private let storage = LockedValue<[SpanRecord]>([])

    var records: [SpanRecord] {
        storage.withLock { $0 }
    }

    func export(_ record: SpanRecord) {
        storage.withLock { $0.append(record) }
    }
}
