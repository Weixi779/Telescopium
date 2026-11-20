//
//  LoggerTests.swift
//  Telescopium
//
//  Created by weixi on 2025/09/05.
//  Copyright © 2026 Telescopium.
//

import Testing
import Foundation
@testable import Telescopium

private struct CallbackRecorder: LogRecording {
    let onRecord: @Sendable (LogRecord) -> Void

    func record(_ record: LogRecord) {
        onRecord(record)
    }
}

private final class CaptureExporter: LogExporter {
    private let storage = LockedValue<[LogRecord]>([])

    var records: [LogRecord] {
        storage.withLock { $0 }
    }

    func export(_ record: LogRecord) {
        storage.withLock { $0.append(record) }
    }
}

private struct TestRedactor: LogRedactor {
    let suffix: String
    let policy: RedactionPolicy
    
    init(suffix: String, policy: RedactionPolicy = .always) {
        self.suffix = suffix
        self.policy = policy
    }
    
    func redact(_ record: LogRecord) -> LogRecord {
        record.replacing(message: record.message + suffix)
    }
}

@Suite(.serialized)
struct LoggerTests {

@Test("Logger struct initialization with string category")
func testLoggerInitWithString() async throws {
    let logger = Logger(category: "TestCategory")
    logger.info("Test initialization")
}

@Test("Logger struct initialization with default category")
func testLoggerInitWithDefault() async throws {
    let logger = Logger()
    logger.info("Default logger test")
}

@Test("Logger methods execute without throwing")
func testLoggerMethods() async throws {
    let logger = Logger()
    
    logger.debug("Debug message")
    logger.info("Info message")
    logger.error("Error message")
}


@Test("A warning captures its caller and error through redaction and export")
func testRecordContext() throws {
    let exporter = CaptureExporter()
    let recorder = LogRecorder(
        redactors: [TestRedactor(suffix: "_redacted")],
        exporters: [exporter]
    )
    let logger = Logger(category: "Playback", recorder: recorder)
    let timeout = URLError(.timedOut)
    // Keep both calls on one line to verify that their columns distinguish them.
    let line = #line + 1
    logger.warning("Retry", error: timeout, metadata: ["attempt": 2]); logger.error("Playback stopped")

    let records = exporter.records
    try #require(records.count == 2)
    let retry = records[0]
    #expect(retry.level == .warning)
    #expect(retry.message == "Retry_redacted")
    #expect(retry.metadata == ["attempt": 2])
    #expect(retry.location.fileID == #fileID)
    #expect(retry.location.function == #function)
    #expect(retry.location.line == line)
    #expect(records[1].location.line == line)
    #expect(retry.location.column > 0)
    #expect(records[1].location.column > retry.location.column)
    #expect(retry.error == LogErrorInfo(timeout))
    #expect(records[1].error == nil)

    let data = try JSONEncoder().encode(retry)
    let decoded = try JSONDecoder().decode(LogRecord.self, from: data)
    #expect(decoded.location == retry.location)
    #expect(decoded.error == retry.error)
}

@Test("Logger measure method")
func testLoggerMeasure() async throws {
    let logger = Logger(category: "TestTimer")
    
    let result = logger.measure("test_operation") {
        usleep(10000) // 10ms
        return 42
    }
    
    #expect(result == 42)
}

@Test("Logger measureAsync method")
func testLoggerMeasureAsync() async throws {
    let logger = Logger(category: "TestTimer")
    
    let result = await logger.measureAsync("test_async_operation") {
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return "async_result"
    }
    
    #expect(result == "async_result")
}

@Test("Logger start/end interval")
func testLoggerInterval() async throws {
    let logger = Logger(category: "TestTimer")
    
    let state = logger.startInterval("manual_interval")
    usleep(10000) // 10ms  
    logger.endInterval("manual_interval", state: state)
}

@Test("Logger event")
func testLoggerEvent() async throws {
    let logger = Logger(category: "TestTimer")
    
    logger.event("test_event")
    logger.event("test_event_with_message", "This is a test message")
}

@Test("Metadata overrides apply to one record from one logger")
func testRecordMetadataOverrides() throws {
    let exporter = CaptureExporter()
    let recorder = LogRecorder(
        redactors: [TestRedactor(suffix: "_redacted")],
        exporters: [exporter]
    )
    let defaults: [String: Any] = [
        "module": "Playback",
        "source": "app",
        "route": ["host": "primary", "port": 443],
        "codes": [1, 2]
    ]
    let logger = Logger(category: "Playback", metadata: defaults, recorder: recorder)
    let itemID = "episode-123"
    let attempt = 2
    logger.warning(
        "Retry",
        metadata: [
            "itemID": itemID, "attempt": attempt, "source": NSNull(),
            "route": ["host": "fallback"], "codes": [], "invalid": Date()
        ]
    )
    logger.info("Ready")
    Logger(category: "Playback", recorder: recorder).debug("Separate logger")

    let records = exporter.records
    try #require(records.count == 3)
    let retry = records[0]
    let expected: Metadata = [
        "module": "Playback", "itemID": "episode-123", "attempt": 2, "source": .null,
        "route": ["host": "fallback"], "codes": []
    ]
    #expect(retry.message == "Retry_redacted")
    #expect(retry.metadata == expected)
    #expect(records[1].metadata == [
        "module": "Playback", "source": "app", "route": ["host": "primary", "port": 443], "codes": [1, 2]
    ])
    #expect(records[2].metadata.isEmpty)
    let data = try JSONEncoder().encode(retry)
    #expect(try JSONDecoder().decode(LogRecord.self, from: data).metadata == expected)
    #expect(retry.replacing(metadata: ["masked": true]).metadata == ["masked": true])
}

@Test("An existing logger follows registration and an explicitly bound logger keeps its recorder")
func testRecorderBinding() {
    let previous = Log.currentRecorder
    defer { Log.register(recorder: previous) }

    let playback = Logger(category: "Playback")
    let first = CaptureExporter()
    let second = CaptureExporter()
    let firstRecorder = LogRecorder(exporters: [first])
    let fixed = Logger(category: "Playback", recorder: firstRecorder)

    Log.register(recorder: firstRecorder)
    playback.info("Before")
    Log.register(recorder: LogRecorder(exporters: [second]))
    playback.info("After")
    fixed.info("Fixed")
    Log.register(recorder: LogRecorder(exporters: []))
    playback.info("Silent")
    fixed.info("Still fixed")

    #expect(first.records.map(\.message) == ["Before", "Fixed", "Still fixed"])
    #expect(second.records.map(\.message) == ["After"])
}

@Test("A replacement can record while a call to the previous recorder is still in progress")
func testReplaceWhileRecording() throws {
    let previous = Log.currentRecorder
    defer { Log.register(recorder: previous) }

    let first = CaptureExporter()
    let second = CaptureExporter()
    let entered = DispatchSemaphore(value: 0)
    let resume = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    let logger = Logger(category: "Playback")
    Log.register(
        recorder: CallbackRecorder { record in
            entered.signal()
            guard resume.wait(timeout: .now() + 5) == .success else {
                Issue.record("The in-flight call blocked recorder replacement")
                return
            }
            first.export(record)
        }
    )

    DispatchQueue.global().async {
        logger.info("In flight")
        finished.signal()
    }
    defer { resume.signal() }
    try #require(entered.wait(timeout: .now() + 5) == .success)

    Log.register(recorder: LogRecorder(exporters: [second]))
    logger.info("After replacement")
    #expect(second.records.map(\.message) == ["After replacement"])
    #expect(first.records.isEmpty)

    resume.signal()
    try #require(finished.wait(timeout: .now() + 5) == .success)
    #expect(first.records.map(\.message) == ["In flight"])
}

@Test("Redactors run in order before every exporter and evaluate their policies for each record")
func testRedactionAndExport() throws {
    let enabled = LockedValue(false)
    let first = CaptureExporter()
    let second = CaptureExporter()
    let recorder = LogRecorder(
        redactors: [
            TestRedactor(suffix: "_skipped", policy: .never),
            TestRedactor(suffix: "_one"),
            TestRedactor(suffix: "_two", policy: .when { enabled.withLock { $0 } })
        ],
        exporters: [first, second]
    )
    let logger = Logger(category: "   ", recorder: recorder)
    logger.info("First")
    enabled.withLock { $0 = true }
    logger.fault(
        "Second",
        metadata: ["state": "playing"],
        file: "Playback/Player.swift",
        function: "play()",
        line: 42,
        column: 13
    )

    let records = first.records
    let messages = ["First_one", "Second_one_two"]
    #expect(records.map(\.message) == messages)
    #expect(second.records.map(\.message) == messages)
    let fault = try #require(records.last)
    #expect(fault.category == Logger.defaultCategory)
    #expect(fault.level == .fault)
    #expect(fault.metadata == ["state": "playing"])
    #expect(fault.location == .init(fileID: "Playback/Player.swift", function: "play()", line: 42, column: 13))
}
}
