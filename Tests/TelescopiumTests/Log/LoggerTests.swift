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

private final class CaptureExporterStore: Sendable {
    private let records = LockedValue<[LogRecord]>([])
    
    func append(_ record: LogRecord) {
        records.withLock { $0.append(record) }
    }
    
    func firstRecord() -> LogRecord? {
        records.withLock { $0.first }
    }
    
    func recordCount() -> Int {
        records.withLock { $0.count }
    }
    
    func allRecords() -> [LogRecord] {
        records.withLock { $0 }
    }
}

private final class CaptureExporter: LogExporter {
    let store: CaptureExporterStore
    
    init(store: CaptureExporterStore = CaptureExporterStore()) {
        self.store = store
    }
    
    func export(_ record: LogRecord) {
        store.append(record)
    }
    
    func firstRecord() async -> LogRecord? {
        store.firstRecord()
    }
    
    func recordCount() async -> Int {
        store.recordCount()
    }
    
    func allRecords() async -> [LogRecord] {
        store.allRecords()
    }
}

private func waitForRecord(
    _ exporter: CaptureExporter,
    attempts: Int = 100,
    delayNanoseconds: UInt64 = 10_000_000
) async -> LogRecord? {
    await Task.yield()
    for _ in 0..<attempts {
        if let record = await exporter.firstRecord() {
            return record
        }
        try? await Task.sleep(nanoseconds: delayNanoseconds)
    }
    return nil
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
    LoggerSystem.setup()
    defer { LoggerSystem.setup() }
    let exporter = CaptureExporter()
    LoggerSystem.setup(exporter: exporter, redactors: [TestRedactor(suffix: "_redacted")])
    let logger = Logger(category: "Playback")
    let timeout = URLError(.timedOut)
    // Keep both calls on one line to verify that their columns distinguish them.
    let line = #line + 1
    logger.warning("Retry", error: timeout, metadata: ["attempt": 2]); logger.error("Playback stopped")

    let records = exporter.store.allRecords()
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
    LoggerSystem.setup()
    defer { LoggerSystem.setup() }

    let exporter = CaptureExporter()
    LoggerSystem.setup(exporter: exporter, redactors: [TestRedactor(suffix: "_redacted")])
    let defaults: [String: Any] = [
        "module": "Playback",
        "source": "app",
        "route": ["host": "primary", "port": 443],
        "codes": [1, 2]
    ]
    let logger = Logger(category: "Playback", metadata: defaults)
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
    Logger(category: "Playback").debug("Separate logger")

    let records = exporter.store.allRecords()
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

@Test("Changing redactors preserves the selected exporters until they are explicitly replaced")
func testExporterConfiguration() {
    LoggerSystem.setup()
    defer { LoggerSystem.setup() }
    let logger = Logger(category: "Playback")
    let first = CaptureExporter()
    let second = CaptureExporter()
    let redactor = TestRedactor(suffix: "_redacted")

    LoggerSystem.addExporter(first)
    LoggerSystem.setup(redactors: [redactor])
    logger.info("First")
    LoggerSystem.setup(exporter: second)
    logger.info("Second")
    LoggerSystem.setup(exporters: [])
    LoggerSystem.setup(redactors: [redactor])
    logger.info("Disabled")
    LoggerSystem.addExporter(first)
    logger.info("Resumed")
    LoggerSystem.setup()
    logger.info("Restored")

    #expect(first.store.allRecords().map(\.message) == ["First_redacted", "Resumed_redacted"])
    #expect(second.store.allRecords().map(\.message) == ["Second"])
}

@Test("Logger pipeline behavior")
func testLoggerPipelineBehavior() async throws {
    LoggerSystem.setup()
    defer { LoggerSystem.setup() }
    
    do {
        let exporter = CaptureExporter()
        LoggerSystem.setup(exporter: exporter)
        
        let logger = Logger(category: "Export")
        logger.warning("Retrying playback")
        
        let record = try #require(await waitForRecord(exporter))
        #expect(record.level == .warning)
        #expect(record.message == "Retrying playback")
    }
    
    LoggerSystem.setup()
    do {
        let exporter = CaptureExporter()
        let redactor = TestRedactor(suffix: "_redacted", policy: .never)
        LoggerSystem.setup(
            exporter: exporter,
            redactors: [redactor]
        )
        
        let logger = Logger(category: "Redaction")
        logger.info("Original")
        
        #expect((await waitForRecord(exporter))?.message == "Original")
    }
    
    LoggerSystem.setup()
    do {
        let exporter = CaptureExporter()
        let redactor = TestRedactor(suffix: "_redacted", policy: .always)
        LoggerSystem.setup(
            exporter: exporter,
            redactors: [redactor]
        )
        
        let logger = Logger(category: "Redaction")
        logger.fault(
            "Original",
            metadata: ["state": "playing"],
            file: "Playback/Player.swift",
            function: "play()",
            line: 42,
            column: 13
        )
        
        let record = try #require(await waitForRecord(exporter))
        #expect(record.message == "Original_redacted")
        #expect(record.level == .fault)
        #expect(record.metadata == ["state": "playing"])
        #expect(record.location == .init(fileID: "Playback/Player.swift", function: "play()", line: 42, column: 13))
    }
    
    LoggerSystem.setup()
    do {
        let exporter = CaptureExporter()
        LoggerSystem.setup(exporter: exporter)
        
        let logger = Logger(category: "   ")
        logger.info("Default category")
        
        #expect((await waitForRecord(exporter))?.category == Logger.defaultCategory)
    }
    
    LoggerSystem.setup()
    do {
        let firstExporter = CaptureExporter()
        let secondExporter = CaptureExporter()
        let firstRedactor = TestRedactor(suffix: "_one")
        let secondRedactor = TestRedactor(suffix: "_two")
        
        LoggerSystem.setup(
            exporters: [firstExporter, secondExporter],
            redactors: [firstRedactor, secondRedactor]
        )
        
        let logger = Logger(category: "Pipeline")
        logger.info("Multiple")
        
        #expect((await waitForRecord(firstExporter))?.message == "Multiple_one_two")
        #expect((await waitForRecord(secondExporter))?.message == "Multiple_one_two")
    }
    
    LoggerSystem.setup()
    do {
        let firstExporter = CaptureExporter()
        let secondExporter = CaptureExporter()
        let firstRedactor = TestRedactor(suffix: "_first")
        let secondRedactor = TestRedactor(suffix: "_second")
        let logger = Logger(category: "HotSwap")
        
        LoggerSystem.setup(exporter: firstExporter)
        logger.info("Before")
        
        LoggerSystem.addRedactor(firstRedactor)
        LoggerSystem.addExporter(secondExporter)
        logger.info("After add")
        
        LoggerSystem.setup(exporters: [secondExporter], redactors: [secondRedactor])
        logger.info("After replace")
        
        #expect(await firstExporter.recordCount() == 2)
        #expect(await secondExporter.recordCount() == 2)
        #expect((await firstExporter.allRecords()).map(\.message) == ["Before", "After add_first"])
        #expect((await secondExporter.allRecords()).map(\.message) == ["After add_first", "After replace_second"])
        
        LoggerSystem.removeAllExporters()
        LoggerSystem.removeAllRedactors()
        logger.info("After remove")
        
        #expect(await firstExporter.recordCount() == 2)
        #expect(await secondExporter.recordCount() == 2)
    }
}

}
