//
//  LogEnricher.swift
//  Telescopium
//
//  Created by weixi on 2026/11/25.
//  Copyright © 2026 Telescopium.
//

/// Adds information available in the logging caller's context.
///
/// After creating each record, `Logger` runs the registered enrichers synchronously
/// in configuration order. Each receives the previous result, and the selected
/// recorder (including an explicitly supplied one) receives the final record.
public protocol LogEnricher: LogRecordProcessor {}
