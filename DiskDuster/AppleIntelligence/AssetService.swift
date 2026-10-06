//
//  AssetService.swift
//  DiskDuster
//

import Darwin
import Foundation
import ObjectiveC

nonisolated enum AssetServiceError: Error, LocalizedError, Equatable {
    case unavailable(String)
    case rejected(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail): "Apple's model service isn't available: \(detail)"
        case .rejected(let detail): "Apple's model service declined the request: \(detail)"
        case .timedOut: "Apple's model service didn't respond in time."
        }
    }
}

/// The selector the asset service's XPC interface uses to run an operation. Declared here only so Swift can
/// send the message; DiskDuster never implements it.
@objc nonisolated private protocol AssetServiceOperationSending {
    @objc(operationWithConfig:completion:)
    func send(_ request: NSDictionary, reply: @escaping (NSError?) -> Void)
}

/// A thin, fail-closed bridge to Apple's private Unified Asset Framework, which owns the Apple Intelligence
/// models on disk. Every class and selector is looked up at run time; anything missing makes the feature
/// unavailable rather than guessing.
nonisolated enum AssetService {
    private static let binaryPath =
        "/System/Library/PrivateFrameworks/UnifiedAssetFramework.framework/UnifiedAssetFramework"
    private static let serviceName = "com.apple.siri.uaf.subscription.service"
    private static let isLoaded: Bool = dlopen(binaryPath, RTLD_NOW) != nil

    static var isAvailable: Bool {
        isLoaded && currentAssetType(of: .foundation) != nil
    }

    /// The MobileAsset type macOS currently associates with a model pack, or nil if it doesn't know the pack.
    static func currentAssetType(of pack: AIModelPack) -> String? {
        guard isLoaded,
              let manager = callClass("UAFConfigurationManager", "defaultManager"),
              let assetSet = call(manager, "getAssetSet:", with: pack.rawValue as NSString),
              let type = call(assetSet, "autoAssetType") as? String else { return nil }
        return type
    }

    /// Bytes on disk per MobileAsset type, from the asset service's own inventory. Nil if it can't be read.
    static func installedBytesByAssetType() -> [String: Int64]? {
        guard isLoaded, let raw = callClass("UAFAssetSetManager", "generateInformationWithError:", with: nil) else {
            return nil
        }
        let inventory: Any?
        if let json = raw as? String, let data = json.data(using: .utf8) {
            inventory = try? JSONSerialization.jsonObject(with: data)
        } else {
            inventory = raw
        }
        guard let root = inventory as? [String: Any], let assets = root["SystemAssets"] as? [[String: Any]] else {
            return nil
        }
        return tallyPresentAssets(assets)
    }

    /// Sums the unarchived size of every asset the inventory says is on this Mac, grouped by asset type.
    static func tallyPresentAssets(_ assets: [[String: Any]]) -> [String: Int64] {
        var totals: [String: Int64] = [:]
        for asset in assets where (asset["isPresentOnDevice"] as? Bool) == true {
            guard let info = asset["metadata"] as? [String: Any], let type = info["AssetType"] as? String else {
                continue
            }
            let sizeValue = info["com.apple.UnifiedAssetFramework.UnarchivedSize"] ?? info["_UnarchivedSize"]
            totals[type, default: 0] += int64(from: sizeValue)
        }
        return totals
    }

    private static func int64(from value: Any?) -> Int64 {
        switch value {
        case let number as NSNumber: number.int64Value
        case let text as String: Int64(text) ?? 0
        default: 0
        }
    }

    /// Asks the asset service to delete the downloaded files for exactly one pack.
    @concurrent
    static func removeDownloadedFiles(of pack: AIModelPack, timeout: Duration = .seconds(120))
        async throws(AssetServiceError) {
        guard isLoaded else { throw .unavailable("the framework could not be loaded") }
        guard let interface = callClass("UAFXPCProxyServiceInterface", "defaultInterface") as? NSXPCInterface else {
            throw .unavailable("its interface could not be found")
        }
        guard protocolDeclares(interface.protocol, "operationWithConfig:completion:") else {
            throw .unavailable("it no longer accepts operations")
        }
        // The service treats a missing or empty list as "every set", so always name exactly one.
        let request: NSDictionary = ["Operation": "ResetAssetSets", "AssetSets": [pack.rawValue]]
        let connection = NSXPCConnection(machServiceName: serviceName, options: [])
        connection.remoteObjectInterface = interface
        connection.resume()
        defer { connection.invalidate() }

        let outcome = OneShot<AssetServiceError?>()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            outcome.deliver(.unavailable(error.localizedDescription))
        }
        (proxy as AnyObject).send?(request) { error in
            outcome.deliver(error.map { .rejected($0.localizedDescription) })
        }
        if let failure = await outcome.wait(timeout: timeout, onTimeout: .timedOut) {
            throw failure
        }
    }

    // MARK: - Runtime helpers

    private static func callClass(_ className: String, _ selectorName: String, with argument: AnyObject? = nil)
        -> AnyObject? {
        guard let cls = NSClassFromString(className) else { return nil }
        return call(cls as AnyObject, selectorName, with: argument)
    }

    private static func call(_ target: AnyObject, _ selectorName: String, with argument: AnyObject? = nil)
        -> AnyObject? {
        let selector = NSSelectorFromString(selectorName)
        guard target.responds(to: selector) else { return nil }
        let takesArgument = selectorName.hasSuffix(":")
        let result = takesArgument ? target.perform(selector, with: argument) : target.perform(selector)
        return result?.takeUnretainedValue()
    }

    /// An XPC proxy claims to respond to everything, so check what its protocol actually declares.
    private static func protocolDeclares(_ proto: Protocol, _ selectorName: String) -> Bool {
        let wanted = NSSelectorFromString(selectorName)
        for required in [true, false] {
            var count: UInt32 = 0
            guard let list = protocol_copyMethodDescriptionList(proto, required, true, &count) else { continue }
            defer { free(list) }
            for index in 0..<Int(count) where list[index].name == wanted {
                return true
            }
        }
        return false
    }
}

/// Delivers the first of several possible results (reply, connection error or timeout) exactly once.
nonisolated final class OneShot<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?
    private var waiter: CheckedContinuation<Value, Never>?
    private var finished = false

    func deliver(_ result: Value) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: result)
        } else {
            value = result
            lock.unlock()
        }
    }

    func wait(timeout: Duration, onTimeout: Value) async -> Value {
        let timer = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            self?.deliver(onTimeout)
        }
        defer { timer.cancel() }
        return await withCheckedContinuation { continuation in
            lock.lock()
            if finished, let value {
                lock.unlock()
                continuation.resume(returning: value)
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }
}
