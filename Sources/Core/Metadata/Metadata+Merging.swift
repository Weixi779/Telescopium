//
//  Metadata+Merging.swift
//  Telescopium
//
//  Created by weixi on 2026/11/18.
//  Copyright © 2026 Telescopium.
//

extension Metadata {
    /// Returns the combined fields, replacing each matching top-level value with its override.
    func merging(overrides: Self) -> Self {
        if overrides.isEmpty { return self }
        if isEmpty { return overrides }
        return merging(overrides) { _, override in override }
    }
}
