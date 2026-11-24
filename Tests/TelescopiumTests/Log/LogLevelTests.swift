//
//  LogLevelTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Telescopium
import Testing

struct LogLevelTests {
    @Test("All cases are ordered by severity")
    func severityOrder() {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .fault]
        #expect(LogLevel.allCases == levels)
        #expect(levels.reversed().sorted() == levels)
        #expect(levels.map(\.rawValue) == ["debug", "info", "warning", "error", "fault"])
    }

    @Test("Text round-trips and accepts mixed case", arguments: LogLevel.allCases)
    func text(_ level: LogLevel) {
        #expect(String(level) == level.rawValue)
        #expect(LogLevel(String(level)) == level)
        #expect(LogLevel(level.rawValue.capitalized) == level)
        #expect(LogLevel(rawValue: level.rawValue.capitalized) == nil)
    }

    @Test("Unknown names are rejected")
    func unknownName() {
        #expect(LogLevel("verbose") == nil)
    }

    @Test("Each level round-trips as its lowercase raw value", arguments: LogLevel.allCases)
    func codable(_ level: LogLevel) throws {
        let string = Data("\"\(level.rawValue)\"".utf8)
        #expect(try JSONEncoder().encode(level) == string)
        #expect(try JSONDecoder().decode(LogLevel.self, from: string) == level)
    }

    @Test(
        "Stored levels require an exact raw value",
        arguments: [#""verbose""#, #""WARNING""#],
    )
    func invalidEncoding(_ json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LogLevel.self, from: Data(json.utf8))
        }
    }
}
