//
//  LogSourceLocation.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

/// The source position where the caller emitted a log record.
public struct LogSourceLocation: Sendable, Codable, Equatable {
    public let fileID: String
    public let function: String
    public let line: Int
    public let column: Int

    public init(fileID: String, function: String, line: Int, column: Int) {
        self.fileID = fileID
        self.function = function
        self.line = line
        self.column = column
    }
}
