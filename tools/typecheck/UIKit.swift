// Minimal UIKit stand-in for the Linux type-check harness (see SwiftUI.swift).
@_exported import Foundation

public class UIImpactFeedbackGenerator {
    public enum FeedbackStyle { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle) {}
    public func impactOccurred() {}
}

public class UINotificationFeedbackGenerator {
    public enum FeedbackType { case success, warning, error }
    public init() {}
    public func notificationOccurred(_ t: FeedbackType) {}
}

public class UIApplication {
    @MainActor public static let shared = UIApplication()
    public var isIdleTimerDisabled = false
}
