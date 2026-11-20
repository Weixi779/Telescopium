//
//  ServiceRegistry.swift
//  Telescopium
//
//  Created by weixi on 2026/11/20.
//  Copyright © 2026 Telescopium.
//

/// Holds the current implementation registered for each service type.
final class ServiceRegistry: Sendable {
    static let application = ServiceRegistry()

    private let services = LockedValue<[ObjectIdentifier: any Sendable]>([:])

    func register<Service: Sendable>(_ type: Service.Type, instance: Service) {
        let previous = services.withLock {
            $0.updateValue(instance, forKey: ObjectIdentifier(type))
        }
        // A replaced service may access the registry from its deinitializer.
        withExtendedLifetime(previous) {}
    }

    func resolve<Service: Sendable>(_ type: Service.Type) -> Service? {
        let service = services.withLock { $0[ObjectIdentifier(type)] }
        return service.flatMap { $0 as? Service }
    }
}
