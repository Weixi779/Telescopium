//
//  Log.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Configures enrichment and recording for the application's loggers.
public enum Log {
    struct Configuration: Sendable {
        let recorder: any LogRecording
        let enrichers: [any LogEnricher]
    }

    private static let fallback = Configuration(recorder: LogRecorder(), enrichers: [])

    /// Replaces the application recorder and ordered enrichers together.
    /// Each log call uses one configuration. Explicitly bound loggers use its enrichers
    /// and continue sending the result to their own recorder.
    public static func register(
        recorder: any LogRecording,
        enrichers: [any LogEnricher] = [],
    ) {
        let configuration = Configuration(recorder: recorder, enrichers: enrichers)
        ServiceRegistry.application.register(Configuration.self, instance: configuration)
    }

    static var currentConfiguration: Configuration {
        ServiceRegistry.application.resolve(Configuration.self) ?? fallback
    }
}
