//
//  ServiceRegistryTests.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

import Dispatch
import Testing
@testable import Telescopium

private protocol FirstService: AnyObject, Sendable {}
private protocol SecondService: AnyObject, Sendable {}
private final class SharedService: FirstService, SecondService {}

private final class ServiceWithCleanup: Sendable {
    let cleanup: @Sendable () -> Void

    init(cleanup: @escaping @Sendable () -> Void) {
        self.cleanup = cleanup
    }

    deinit { cleanup() }
}

struct ServiceRegistryTests {
    @Test("Replacing a protocol registration only affects that contract in that registry")
    func registerByContract() {
        let registry = ServiceRegistry()
        let original = SharedService()
        let replacement = SharedService()

        registry.register((any FirstService).self, instance: original)
        #expect(registry.resolve((any SecondService).self) == nil)
        #expect(registry.resolve(SharedService.self) == nil)

        registry.register((any SecondService).self, instance: original)
        registry.register((any FirstService).self, instance: replacement)
        #expect(registry.resolve((any FirstService).self) === replacement)
        #expect(registry.resolve((any SecondService).self) === original)
        #expect(ServiceRegistry().resolve((any FirstService).self) == nil)
    }

    @Test("A replaced service can resolve its successor during cleanup")
    func releaseAfterUnlocking() {
        let registry = ServiceRegistry()
        let released = DispatchSemaphore(value: 0)
        let replacement = ServiceWithCleanup {}
        registry.register(
            ServiceWithCleanup.self,
            instance: ServiceWithCleanup {
                #expect(registry.resolve(ServiceWithCleanup.self) === replacement)
                released.signal()
            }
        )

        DispatchQueue.global().async {
            registry.register(ServiceWithCleanup.self, instance: replacement)
        }
        #expect(released.wait(timeout: .now() + 5) == .success)
    }
}
