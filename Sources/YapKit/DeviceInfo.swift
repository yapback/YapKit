// DeviceInfo.swift
// Collects device metadata for feedback submissions

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Device and app metadata included with feedback submissions.
public struct DeviceInfo: Codable, Sendable {
    public let model: String
    public let osVersion: String
    public let appVersion: String
    public let buildNumber: String
    public let locale: String
    
    public init(
        model: String,
        osVersion: String,
        appVersion: String,
        buildNumber: String,
        locale: String
    ) {
        self.model = model
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.locale = locale
    }
    
    /// Collects current device information.
    @MainActor
    public static var current: DeviceInfo {
        DeviceInfo(
            model: modelIdentifier,
            osVersion: osVersionString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            locale: Locale.current.identifier
        )
    }
    
    private static var modelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }
    
    @MainActor
    private static var osVersionString: String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif canImport(AppKit)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #else
        return "Unknown"
        #endif
    }
}
