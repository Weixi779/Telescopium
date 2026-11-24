//
//  LogErrorInfo.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

import Foundation

/// Serializable error details attached to a log record.
public struct LogErrorInfo: Sendable, Codable, Equatable {
    public let typeName: String
    public let message: String
    public let domain: String?
    public let code: Int?

    public init(typeName: String, message: String, domain: String? = nil, code: Int? = nil) {
        self.typeName = typeName
        self.message = message
        self.domain = domain
        self.code = code
    }

    public init(_ error: any Error) {
        let errorType = type(of: error)
        // Bridging an ordinary Swift error would manufacture a domain and code.
        let nsError = errorType is NSError.Type || error is any CustomNSError ? error as NSError : nil
        let message = (error as? any LocalizedError)?.errorDescription
            ?? nsError?.localizedDescription
            ?? String(describing: error)

        self.init(
            typeName: String(reflecting: errorType),
            message: message,
            domain: nsError?.domain,
            code: nsError?.code,
        )
    }
}
