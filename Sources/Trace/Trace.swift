//
//  Trace.swift
//  Telescopium
//
//  Created by weixi on 2026/11/24.
//  Copyright © 2026 Telescopium.
//

/// Configures the tracer used by the application's scoped operations.
public enum Trace {
    private static let fallback = TelescopiumTracer()

    /// Replaces the tracer for new spans. Active spans finish with the tracer that started them.
    public static func register(tracer: any Tracer) {
        ServiceRegistry.application.register((any Tracer).self, instance: tracer)
    }

    static var currentTracer: any Tracer {
        ServiceRegistry.application.resolve((any Tracer).self) ?? fallback
    }
}
