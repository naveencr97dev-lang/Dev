// Minimal Swift Charts stand-in for the Linux type-check harness (see SwiftUI.swift).
import SwiftUI

public protocol ChartContent {}
public struct PlottableValue { }
extension PlottableValue {
    public static func value<V>(_ label: String, _ v: V) -> PlottableValue { PlottableValue() }
}
public struct MarkDimension { public static func ratio(_ r: Double) -> MarkDimension { MarkDimension() } }
public enum AnnotationPosition { case top, bottom, leading, trailing, overlay }
public struct BarMark: ChartContent {
    public init(x: PlottableValue, y: PlottableValue, width: MarkDimension = .ratio(1)) {}
    public func foregroundStyle(by v: PlottableValue) -> BarMark { self }
    public func position(by v: PlottableValue) -> BarMark { self }
    public func annotation<C: View>(position: AnnotationPosition = .top, spacing: CGFloat? = nil,
                                    @ViewBuilder content: () -> C) -> BarMark { self }
}
public struct Chart: View {
    public init<D: RandomAccessCollection, C: ChartContent>(_ data: D, content: @escaping (D.Element) -> C) {}
    public var body: Never { fatalError() }
}
public struct AxisValueLabel: View { public init() {}; public var body: Never { fatalError() } }
public struct AxisMarks<C: View>: View {
    public init<V>(values: [V], @ViewBuilder content: @escaping (Int) -> C) {}
    public var body: Never { fatalError() }
}
extension View {
    public func chartForegroundStyleScale(domain: [String], range: [Color]) -> _Mod { _Mod() }
    public func chartXAxis<C: View>(@ViewBuilder content: () -> C) -> _Mod { _Mod() }
}
