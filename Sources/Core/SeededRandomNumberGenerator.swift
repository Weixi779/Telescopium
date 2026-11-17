//
//  SeededRandomNumberGenerator.swift
//  Telescopium
//
//  Created by weixi on 2026/11/17.
//  Copyright © 2026 Telescopium.
//

/// A deterministic SplitMix64 generator for reproducible tests and debugging.
/// Algorithm reference: https://prng.di.unimi.it/splitmix.c
///
/// The same seed and sequence of `next()` calls produce the same output sequence.
/// This is not a cryptographically secure generator. Use the default system random
/// source for production trace identifiers; reusing a seed repeats identifiers.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}
