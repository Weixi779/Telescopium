//
//  Log.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Configures the recorder used by the application's loggers.
public enum Log {
    private static let fallback = LogRecorder()

    /// Replaces the application recorder. Each log call uses the recorder it acquired.
    /// Loggers initialized with an explicit recorder keep using it.
    public static func register(recorder: any LogRecording) {
        ServiceRegistry.application.register((any LogRecording).self, instance: recorder)
    }

    static var currentRecorder: any LogRecording {
        ServiceRegistry.application.resolve((any LogRecording).self) ?? fallback
    }
}
