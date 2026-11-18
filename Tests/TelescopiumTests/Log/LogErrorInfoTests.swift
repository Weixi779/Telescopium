//
//  LogErrorInfoTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation
import Telescopium
import Testing

struct LogErrorInfoTests {
    enum PlaybackError: Error { case stopped }

    enum AudioError: LocalizedError, CustomNSError {
        case unavailable

        static var errorDomain: String { "Playback.Audio" }
        var errorCode: Int { 7 }
        var errorDescription: String? { "Audio unavailable" }
    }

    @Test("An erased Swift error retains its concrete type and description")
    func swiftError() {
        let error: any Error = PlaybackError.stopped
        let info = LogErrorInfo(error)
        #expect(info.typeName == String(reflecting: PlaybackError.self))
        #expect(info.message == "stopped")
        #expect(info.domain == nil)
        #expect(info.code == nil)
    }

    @Test("A custom Swift error supplies its localized description, domain and code")
    func customNSError() {
        let info = LogErrorInfo(AudioError.unavailable)
        #expect(info.typeName == String(reflecting: AudioError.self))
        #expect(info.message == "Audio unavailable")
        #expect(info.domain == "Playback.Audio")
        #expect(info.code == 7)
    }

    @Test("Foundation errors preserve their domain and code")
    func foundationError() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "Offline"]
        )
        let info = LogErrorInfo(error)
        #expect(info.message == "Offline")
        #expect(info.domain == NSURLErrorDomain)
        #expect(info.code == NSURLErrorNotConnectedToInternet)

        let urlError = LogErrorInfo(URLError(.timedOut))
        #expect(urlError.domain == NSURLErrorDomain)
        #expect(urlError.code == NSURLErrorTimedOut)
    }
}
