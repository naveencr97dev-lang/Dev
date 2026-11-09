// Minimal AVFoundation stand-ins for the Linux type-check (Apple's signatures, no behaviour).
import Foundation

open class AVAudioPlayer: NSObject {
    public init(contentsOf url: URL) throws {}
    open var numberOfLoops: Int = 0
    open var volume: Float = 1
    open var isPlaying: Bool { false }
    open var currentTime: TimeInterval = 0
    @discardableResult open func prepareToPlay() -> Bool { true }
    @discardableResult open func play() -> Bool { true }
    open func pause() {}
    open func stop() {}
    open func setVolume(_ volume: Float, fadeDuration duration: TimeInterval) {}
}

open class AVAudioSession: NSObject {
    public struct Category: Hashable {
        public let rawValue: String
        public static let ambient = Category(rawValue: "AVAudioSessionCategoryAmbient")
        public static let playback = Category(rawValue: "AVAudioSessionCategoryPlayback")
    }
    public struct Mode: Hashable {
        public let rawValue: String
        public static let `default` = Mode(rawValue: "AVAudioSessionModeDefault")
    }
    public struct CategoryOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1)
    }
    public struct SetActiveOptions: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
    }
    public static func sharedInstance() -> AVAudioSession { AVAudioSession() }
    open func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws {}
    open func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}
}
