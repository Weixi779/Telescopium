//
//  TraceCorrelationEnricher.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

/// Fills an unassigned trace parent from the span bound to the logging call site.
public struct TraceCorrelationEnricher: LogEnricher {
    public init() {}

    public func process(_ record: LogRecord) -> LogRecord {
        guard record.traceParent == nil, let traceParent = TraceScope.current?.traceParent else {
            return record
        }
        var enriched = record
        enriched.traceParent = traceParent
        return enriched
    }
}
