//
//  PlaybackExportTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

#if OpenTelemetry && Datadog
import Foundation
import Testing
import XCTest
import DatadogCore
import DatadogLogs
import OpenTelemetryApi
import OpenTelemetrySdk
import TelescopiumDatadog
import TelescopiumOpenTelemetry
@testable import Telescopium

private final class CapturingOTelExporter: LogRecordExporter {
    let records = LockedValue<[ReadableLogRecord]>([])

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        records.withLock { $0.append(contentsOf: logRecords) }
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult { .success }
    func shutdown(explicitTimeout: TimeInterval?) {}
}

private struct LocalClock: ServerDateProvider {
    func synchronize(update: @escaping (TimeInterval) -> Void) { update(0) }
}

private struct EpisodeRedactor: LogRedactor {
    func process(_ record: LogRecord) -> LogRecord {
        var result = record
        result.metadata["episode_id"] = "***"
        return result
    }
}

private struct BufferingRecorder: LogRecording {
    let pending = LockedValue<LogRecord?>(nil)

    func record(_ record: LogRecord) {
        pending.withLock { $0 = record }
    }
}

struct PlaybackExportTests {
    @Test("Deferred Playback logs preserve captured correlation in both SDKs", .serialized, arguments: [true, false])
    func exportPlaybackWarning(withTrace: Bool) async throws {
        let capture = CapturingOTelExporter()
        let provider = LoggerProviderSdk(
            logRecordProcessors: [SimpleLogRecordProcessor(logRecordExporter: capture)],
        )

        let instance = "TelescopiumPlaybackExportTests"
        let core = Datadog.initialize(
            with: .init(clientToken: "test", env: "test", serverDateProvider: LocalClock()),
            trackingConsent: .pending,
            instanceName: instance,
        )
        defer { Datadog.stopInstance(named: instance) }
        let encoded = LockedValue<Data?>(nil)
        let received = XCTestExpectation(description: "Datadog encoded the Playback event")
        Logs.enable(
            with: .init(eventMapper: { event in
                do {
                    let data = try JSONEncoder().encode(event)
                    encoded.withLock { $0 = data }
                } catch {
                    Issue.record(error)
                }
                received.fulfill()
                return nil
            }),
            in: core,
        )
        let ddLogger = DatadogLogs.Logger.create(
            with: .init(name: "Telescopium", bundleWithTraceEnabled: false),
            in: core,
        )
        let recorder = LogRecorder(
            redactors: [EpisodeRedactor()],
            exporters: [OTelLogExporter(provider: provider), DatadogLogExporter(logger: ddLogger)],
        )
        let (record, parent) = try capturePlaybackWarning(withTrace: withTrace)
        #expect(TraceScope.current == nil)
        if withTrace {
            let tracer = TracerProviderSdk().get(instrumentationName: "Upload")
            tracer.spanBuilder(spanName: "Flush").withActiveSpan { _ in recorder.record(record) }
        } else {
            recorder.record(record)
        }

        let records = capture.records.withLock { $0 }
        try #require(records.count == 1)
        let otel = records[0]
        #expect(otel.spanContext?.traceId.hexString == parent?.traceId.hexString)
        #expect(otel.spanContext?.spanId.hexString == parent?.spanId.hexString)
        #expect(otel.spanContext?.traceFlags.byte == parent?.flags)
        checkOTelRecord(otel)

        let outcome = await XCTWaiter.fulfillment(of: [received], timeout: 5)
        try #require(outcome == .completed)
        let data = try #require(encoded.withLock { $0 })
        try checkDatadogEvent(data, timestamp: otel.timestamp, parent: parent)
    }

    private func capturePlaybackWarning(withTrace: Bool) throws -> (LogRecord, TraceParent?) {
        let previous = Log.currentConfiguration
        defer { Log.register(recorder: previous.recorder, enrichers: previous.enrichers) }
        let buffer = BufferingRecorder()
        Log.register(recorder: buffer, enrichers: [TraceCorrelationEnricher()])
        let playback = Telescopium.Logger(category: "Playback", metadata: ["episode_id": "ep-42"])
        let route: [String: Any] = [
            "attempt": 2,
            "steps": [true, NSNull(), ["bytes": Data([0, 255])]] as [Any],
            "latency": 1.5,
            "limit": Double.infinity,
            "fallback": NSNull(),
            "empty": [String: Any](),
        ]
        let error = NSError(domain: "player", code: 17, userInfo: [NSLocalizedDescriptionKey: "Stopped"])
        func warn() {
            playback.warning(
                "Retry playback",
                error: error,
                metadata: ["route": route],
                file: "Playback/Player.swift",
                function: "play()",
                line: 42,
                column: 9,
            )
        }
        let parent: TraceParent?
        if withTrace {
            let incoming = try #require(TraceParent(headerValue: "00-00abcdef123456780000000000000001-0000000000000001-a3"))
            parent = TraceScope.$current.withValue(.init(traceParent: incoming, isRemote: true)) {
                withSpan("Playback") { span in
                    warn()
                    return span.context.traceParent
                }
            }
        } else {
            warn()
            parent = nil
        }
        return try (#require(buffer.pending.withLock { $0 }), parent)
    }

    private func checkOTelRecord(_ otel: ReadableLogRecord) {
        #expect(otel.instrumentationScopeInfo.name == "Playback")
        #expect(otel.severity == .warn)
        #expect(otel.body == .string("Retry playback"))
        #expect(otel.attributes["episode_id"] == .string("***"))
        #expect(otel.attributes["exception.message"] == .string("Stopped"))
        #expect(otel.attributes["code.line.number"] == .int(42))
        let expected = AttributeSet(
            labels: [
                "attempt": .int(2),
                "steps": .array(.init(values: [
                    .bool(true), .string("null"), .set(.init(labels: ["bytes": .string("AP8=")])),
                ])),
                "latency": .double(1.5),
                "limit": .double(.infinity),
                "fallback": .string("null"),
                "empty": .set(.init(labels: [:])),
            ],
        )
        #expect(otel.attributes["route"] == .set(expected))
    }

    private func checkDatadogEvent(_ data: Data, timestamp: Date, parent: TraceParent?) throws {
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["trace_id"] as? String == parent?.traceId.hexString)
        #expect(json["span_id"] as? String == parent?.spanId.hexString)
        #expect(json["message"] as? String == "Retry playback")
        #expect(json["status"] as? String == "warn")
        #expect(json["logger.name"] as? String == "Telescopium")
        #expect(json["episode_id"] as? String == "***")
        let expectedRoute: NSDictionary = [
            "attempt": 2,
            "steps": [true, NSNull(), ["bytes": "AP8="]] as [Any],
            "latency": 1.5,
            "limit": "Infinity",
            "fallback": NSNull(),
            "empty": [:] as NSDictionary,
        ]
        #expect(json["route"] as? NSDictionary == expectedRoute)
        let context = try #require(json["telescopium"] as? [String: Any])
        #expect(context["category"] as? String == "Playback")
        #expect(context["timestamp_ms"] as? Int64 == Int64(timestamp.timeIntervalSince1970 * 1000))
        #expect((context["location"] as? [String: Any])?["column"] as? Int == 9)
        #expect((context["error"] as? [String: Any])?["code"] as? Int == 17)
    }
}
#endif
