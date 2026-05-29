import Foundation
import VietmapTrackingSDK
import ObjectiveC.runtime

/// Thin wrapper around `VietmapTrackingManager.shared` that exposes
/// additional SDK methods not yet on the manager's public API at call-sites
/// where the plugin file must stay clean.
///
/// All new zone-network-v2 methods are surfaced here so that
/// `VietmapTrackingPlugin.swift` can call `VietmapTrackingWrapper.shared.*`
/// without importing the SDK type directly in every handler.
final class VietmapTrackingWrapper {

    static let shared = VietmapTrackingWrapper()

    private let manager = VietmapTrackingManager.shared

    private init() {}

    // MARK: - Zone Network V2

    /// Configure the alternative zone-network endpoint for speed-alert look-ups.
    ///
    /// Returns `false` when the currently linked SDK does not expose this API.
    func configureZoneNetworkV2(baseUrl: String) -> Bool {
        guard let obj = manager as? NSObject else {
            return false
        }

        // Try common Obj-C selector names to support multiple SDK builds.
        let selectors = [
            NSSelectorFromString("configureZoneNetworkV2WithBaseUrl:"),
            NSSelectorFromString("configureZoneNetworkV2:")
        ]

        for sel in selectors where obj.responds(to: sel) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Void
            let imp = obj.method(for: sel)
            let fn = unsafeBitCast(imp, to: Fn.self)
            fn(obj, sel, baseUrl as NSString)
            return true
        }

        return false
    }

    /// Reset the zone-network-v2 configuration back to the SDK default.
    ///
    /// Returns `false` when the currently linked SDK does not expose this API.
    func resetZoneNetworkV2() -> Bool {
        guard let obj = manager as? NSObject else {
            return false
        }

        let selectors = [
            NSSelectorFromString("resetZoneNetworkV2"),
            NSSelectorFromString("resetZoneNetworkV2:")
        ]

        for sel in selectors where obj.responds(to: sel) {
            typealias Fn = @convention(c) (AnyObject, Selector) -> Void
            let imp = obj.method(for: sel)
            let fn = unsafeBitCast(imp, to: Fn.self)
            fn(obj, sel)
            return true
        }

        return false
    }
}
