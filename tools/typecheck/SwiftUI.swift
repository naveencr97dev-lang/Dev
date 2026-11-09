// Minimal SwiftUI stand-in so the app's Swift can be TYPE-CHECKED on Linux (no Mac here).
// It is permissive on purpose: it checks our own code (model names, optionals, closures, types),
// not every detail of Apple's API. A clean run here is not a guarantee Xcode will accept the code,
// but it catches most mistakes before a Codemagic build. Extend it when new APIs are used.
@_exported import Foundation

// MARK: - Core

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

extension Never: View { public var body: Never { fatalError() } }

public struct EmptyView: View { public init() {}; public var body: Never { fatalError() } }
public struct TupleView<T>: View { public var body: Never { fatalError() } }
public struct _ConditionalContent<T: View, F: View>: View { public var body: Never { fatalError() } }
public struct AnyView: View { public init<V: View>(_ v: V) {}; public var body: Never { fatalError() } }
/// Every modifier returns this.
public struct _Mod: View, Shape {
    public init() {}
    public var body: Never { fatalError() }
    public func path(in rect: CGRect) -> Path { Path() }
}
public enum CGLineCap { case butt, round, square }
public struct StrokeStyle {
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, dash: [CGFloat] = []) {}
}
extension Optional: View where Wrapped: View { public var body: Never { fatalError() } }

@resultBuilder public struct ViewBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<C: View>(_ c: C) -> C { c }
    public static func buildBlock<each C: View>(_ c: repeat each C) -> TupleView<(repeat each C)> { TupleView() }
    public static func buildExpression<C: View>(_ c: C) -> C { c }
    public static func buildIf<C: View>(_ c: C?) -> C? { c }
    public static func buildOptional<C: View>(_ c: C?) -> C? { c }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildLimitedAvailability<C: View>(_ c: C) -> AnyView { AnyView(c) }
}

// MARK: - State and environment

@propertyWrapper public struct State<Value> {
    public init(wrappedValue: Value) { v = wrappedValue }
    private var v: Value
    public var wrappedValue: Value { get { v } nonmutating set {} }
    public var projectedValue: Binding<Value> { Binding(get: { v }, set: { _ in }) }
}

@propertyWrapper @dynamicMemberLookup public struct Binding<Value> {
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { g = get }
    public init(projectedValue: Binding<Value>) { g = projectedValue.g }
    private let g: () -> Value
    public var wrappedValue: Value { get { g() } nonmutating set {} }
    public var projectedValue: Binding<Value> { self }
    public static func constant(_ v: Value) -> Binding<Value> { Binding(get: { v }, set: { _ in }) }
    public subscript<T>(dynamicMember kp: WritableKeyPath<Value, T>) -> Binding<T> {
        Binding<T>(get: { self.g()[keyPath: kp] }, set: { _ in })
    }
}

public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public init(wrappedValue: Value) { v = wrappedValue }
    public var wrappedValue: Value { get { v } set { v = newValue } }
    private var v: Value
}
@propertyWrapper public struct EnvironmentObject<O: ObservableObject> {
    public init() {}
    public var wrappedValue: O { fatalError() }
}
@propertyWrapper public struct StateObject<O: ObservableObject> {
    public init(wrappedValue: @autoclosure @escaping () -> O) {}
    public var wrappedValue: O { fatalError() }
}
@propertyWrapper public struct AppStorage<Value> {
    public init(wrappedValue: Value, _ key: String) { v = wrappedValue }
    private var v: Value
    public var wrappedValue: Value { get { v } nonmutating set {} }
    public var projectedValue: Binding<Value> { Binding(get: { v }, set: { _ in }) }
}

public struct DismissAction { public func callAsFunction() {} }
public enum UserInterfaceSizeClass: Hashable { case compact, regular }
public enum EditMode: Hashable { case inactive, active, transient }
public enum ScenePhase: Hashable { case active, inactive, background }
public struct EnvironmentValues {
    public var dismiss: DismissAction { DismissAction() }
    public var verticalSizeClass: UserInterfaceSizeClass? { get { nil } set {} }
    public var horizontalSizeClass: UserInterfaceSizeClass? { get { nil } set {} }
    public var editMode: Binding<EditMode>? { get { nil } set {} }
    public var scenePhase: ScenePhase { get { .active } set {} }
}
@propertyWrapper public struct Environment<Value> {
    public init(_ kp: KeyPath<EnvironmentValues, Value>) {}
    public var wrappedValue: Value { fatalError() }
}

public func withAnimation<R>(_ a: Animation? = .default, _ body: () throws -> R) rethrows -> R { try body() }

// MARK: - Values

public struct Font: Hashable {
    public struct Weight: Hashable {
        public static let ultraLight = Weight(), thin = Weight(), light = Weight(), regular = Weight(), medium = Weight()
        public static let semibold = Weight(), bold = Weight(), heavy = Weight(), black = Weight()
    }
    public struct Width: Hashable { public static let compressed = Width(), condensed = Width(), standard = Width(), expanded = Width() }
    public enum Design: Hashable { case `default`, rounded, monospaced, serif }
    public static let largeTitle = Font(), title = Font(), title2 = Font(), title3 = Font(), headline = Font()
    public static let subheadline = Font(), body = Font(), callout = Font(), footnote = Font(), caption = Font(), caption2 = Font()
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font { Font() }
    public func weight(_ w: Weight) -> Font { self }
    public func width(_ w: Width) -> Font { self }
    public func italic() -> Font { self }
    public func bold() -> Font { self }
    public func monospacedDigit() -> Font { self }
}

public protocol ShapeStyle {}
public struct HierarchicalShapeStyle: ShapeStyle {
    public static let primary = HierarchicalShapeStyle(), secondary = HierarchicalShapeStyle(), tertiary = HierarchicalShapeStyle()
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .primary }
    public static var secondary: HierarchicalShapeStyle { .secondary }
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
}

public struct Color: View, ShapeStyle, Hashable {
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public init(white: Double, opacity: Double = 1) {}
    public var body: Never { fatalError() }
    public func opacity(_ o: Double) -> Color { self }
    public static let white = Color(white: 1), black = Color(white: 0), clear = Color(white: 0, opacity: 0)
    public static let red = Color(white: 0), orange = Color(white: 0), yellow = Color(white: 0), green = Color(white: 0)
    public static let blue = Color(white: 0), purple = Color(white: 0), pink = Color(white: 0), gray = Color(white: 0)
    public static let primary = Color(white: 1), secondary = Color(white: 0.5), accentColor = Color(white: 0)
}
extension ShapeStyle where Self == Color {
    public static var white: Color { .white }
    public static var black: Color { .black }
    public static var clear: Color { .clear }
    public static var red: Color { .red }
    public static var orange: Color { .orange }
    public static var yellow: Color { .yellow }
    public static var green: Color { .green }
    public static var blue: Color { .blue }
    public static var gray: Color { .gray }
}

public struct UnitPoint: Hashable {
    public static let topLeading = UnitPoint(), top = UnitPoint(), topTrailing = UnitPoint(), leading = UnitPoint()
    public static let center = UnitPoint(), trailing = UnitPoint(), bottomLeading = UnitPoint(), bottom = UnitPoint()
    public static let bottomTrailing = UnitPoint()
}
public struct LinearGradient: View, ShapeStyle {
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public var body: Never { fatalError() }
}
public struct RadialGradient: View, ShapeStyle {
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public var body: Never { fatalError() }
}

public struct Animation: Hashable {
    public static let `default` = Animation(), easeInOut = Animation(), easeOut = Animation(), easeIn = Animation()
    public static let linear = Animation()
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.8, blendDuration: Double = 0) -> Animation { Animation() }
    public static func easeInOut(duration: Double) -> Animation { Animation() }
    public static func easeOut(duration: Double) -> Animation { Animation() }
    public static func easeIn(duration: Double) -> Animation { Animation() }
    public static func linear(duration: Double) -> Animation { Animation() }
    public func delay(_ d: Double) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
    public func speed(_ s: Double) -> Animation { self }
}
public struct AnyTransition {
    public static let opacity = AnyTransition(), scale = AnyTransition(), identity = AnyTransition()
    public static func move(edge: Edge) -> AnyTransition { AnyTransition() }
    public func combined(with other: AnyTransition) -> AnyTransition { self }
}

public struct Angle { public static func degrees(_ d: Double) -> Angle { Angle() } }
public enum Edge: Hashable {
    case top, leading, bottom, trailing
    public struct Set: OptionSet, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1), leading = Set(rawValue: 2), bottom = Set(rawValue: 4), trailing = Set(rawValue: 8)
        public static let horizontal: Set = [.leading, .trailing], vertical: Set = [.top, .bottom], all: Set = [.top, .leading, .bottom, .trailing]
    }
}
public struct EdgeInsets: Hashable {
    public init() {}
    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {}
}
public struct HorizontalAlignment: Hashable { public static let leading = Self(), center = Self(), trailing = Self() }
public struct VerticalAlignment: Hashable {
    public static let top = Self(), center = Self(), bottom = Self(), firstTextBaseline = Self(), lastTextBaseline = Self()
}
public struct Alignment: Hashable {
    public static let leading = Self(), trailing = Self(), center = Self(), top = Self(), bottom = Self()
    public static let topLeading = Self(), topTrailing = Self(), bottomLeading = Self(), bottomTrailing = Self()
}
public enum Axis: Hashable {
    case horizontal, vertical
    public struct Set: OptionSet, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1), vertical = Set(rawValue: 2)
    }
}
public enum Visibility: Hashable { case automatic, visible, hidden }
public enum TextAlignment: Hashable { case leading, center, trailing }
public enum RoundedCornerStyle: Hashable { case circular, continuous }
public struct ButtonRole: Hashable { public static let destructive = ButtonRole(), cancel = ButtonRole() }
public enum TextCase: Hashable { case uppercase, lowercase }
public struct TextInputAutocapitalization { public static let words = Self(), sentences = Self(), never = Self(), characters = Self() }
public struct ToolbarItemPlacement {
    public static let navigationBarTrailing = Self(), navigationBarLeading = Self(), automatic = Self()
    public static let principal = Self(), bottomBar = Self(), topBarTrailing = Self(), topBarLeading = Self()
}
public struct ToolbarPlacement { public static let navigationBar = Self(), tabBar = Self(), bottomBar = Self() }
public enum NavigationBarItem { public enum TitleDisplayMode { case automatic, inline, large } }
public struct ScrollIndicatorVisibility { public static let hidden = Self(), visible = Self(), automatic = Self() }

// MARK: - Views

public struct Text: View {
    public init(_ s: String) {}
    public init<S: StringProtocol>(_ s: S) {}
    public var body: Never { fatalError() }
}
public struct Image: View {
    public init(systemName: String) {}
    public init(_ name: String) {}
    public var body: Never { fatalError() }
}
public struct Label<T: View, I: View>: View {
    public var body: Never { fatalError() }
}
extension Label where T == Text, I == Image {
    public init(_ title: String, systemImage: String) {}
}
extension Label {
    public init(@ViewBuilder title: () -> T, @ViewBuilder icon: () -> I) {}
}
public struct Button<L: View>: View {
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> L) {}
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> L) {}
    public var body: Never { fatalError() }
}
extension Button where L == Text {
    public init(_ title: String, action: @escaping () -> Void) {}
    public init(_ title: String, role: ButtonRole?, action: @escaping () -> Void) {}
}
public struct NavigationLink<L: View, D: View>: View {
    public init(@ViewBuilder destination: () -> D, @ViewBuilder label: () -> L) {}
    public var body: Never { fatalError() }
}
extension NavigationLink where D == Never {
    public init<V: Hashable>(value: V?, @ViewBuilder label: () -> L) {}
}
public struct NavigationStack<Root: View>: View {
    public init(@ViewBuilder root: () -> Root) {}
    public init<Data>(path: Binding<Data>, @ViewBuilder root: () -> Root)
        where Data: MutableCollection, Data: RandomAccessCollection, Data: RangeReplaceableCollection, Data.Element: Hashable {}
    public var body: Never { fatalError() }
}
public struct List<C: View>: View {
    public init(@ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct Section<H: View, C: View, F: View>: View {
    public var body: Never { fatalError() }
}
extension Section where H == EmptyView, F == EmptyView {
    public init(@ViewBuilder content: () -> C) {}
}
extension Section where H == Text, F == EmptyView {
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> C) {}
}
extension Section where F == EmptyView {
    public init(@ViewBuilder content: () -> C, @ViewBuilder header: () -> H) {}
}
extension Section where H == EmptyView {
    public init(@ViewBuilder content: () -> C, @ViewBuilder footer: () -> F) {}
}
extension Section {
    public init(@ViewBuilder content: () -> C, @ViewBuilder header: () -> H, @ViewBuilder footer: () -> F) {}
}
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
    public var body: Never { fatalError() }
    public func onMove(perform: ((IndexSet, Int) -> Void)?) -> _Mod { _Mod() }
    public func onDelete(perform: ((IndexSet) -> Void)?) -> _Mod { _Mod() }
}
extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}
extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {}
}
public struct HStack<C: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct VStack<C: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct ZStack<C: View>: View {
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct Group<C: View>: View {
    public init(@ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct ScrollView<C: View>: View {
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct Spacer: View {
    public init(minLength: CGFloat? = nil) {}
    public var body: Never { fatalError() }
}
public struct Divider: View { public init() {}; public var body: Never { fatalError() } }
public struct ProgressView: View { public init() {}; public var body: Never { fatalError() } }
public struct Picker<L: View, T: Hashable, C: View>: View {
    public var body: Never { fatalError() }
}
extension Picker where L == Text {
    public init(_ title: String, selection: Binding<T>, @ViewBuilder content: () -> C) {}
}
public struct Toggle: View {
    public init(_ title: String, isOn: Binding<Bool>) {}
    public var body: Never { fatalError() }
}
public struct Stepper: View {
    public init<S: StringProtocol>(_ title: S, value: Binding<Int>, in bounds: ClosedRange<Int>, step: Int = 1) {}
    public var body: Never { fatalError() }
}
public struct TextField: View {
    public init(_ title: String, text: Binding<String>) {}
    public var body: Never { fatalError() }
}
public struct Menu<C: View, L: View>: View {
    public init(@ViewBuilder content: () -> C, @ViewBuilder label: () -> L) {}
    public var body: Never { fatalError() }
}
public struct ViewThatFits<C: View>: View {
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct GeometryProxy { public var size: CGSize { .zero } }
public struct GeometryReader<C: View>: View {
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> C) {}
    public var body: Never { fatalError() }
}
public struct ToolbarItem<C: View>: View {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}

public protocol Layout {}
public struct HStackLayout: Layout { public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {} }
public struct VStackLayout: Layout { public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) {} }
public struct AnyLayout {
    public init<L: Layout>(_ l: L) {}
    public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> _Mod { _Mod() }
}

// MARK: - Shapes

public struct Path: Shape {
    public init() {}
    public init(_ build: (inout Path) -> Void) {}
    public func path(in rect: CGRect) -> Path { self }
    public init(roundedRect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {}
    public init(ellipseIn: CGRect) {}
    public mutating func move(to p: CGPoint) {}
    public mutating func addLine(to p: CGPoint) {}
    public mutating func addQuadCurve(to p: CGPoint, control: CGPoint) {}
    public mutating func addEllipse(in r: CGRect) {}
    public mutating func addRect(_ r: CGRect) {}
    public mutating func closeSubpath() {}
}
public protocol Shape: View {
    func path(in rect: CGRect) -> Path
}
extension Shape {
    public var body: Never { fatalError() }
    public func fill<S: ShapeStyle>(_ s: S) -> _Mod { _Mod() }
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> _Mod { _Mod() }
    public func stroke<S: ShapeStyle>(_ s: S, style: StrokeStyle) -> _Mod { _Mod() }
    public func trim(from: CGFloat, to: CGFloat) -> _Mod { _Mod() }
}
public struct Rectangle: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Capsule: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct Circle: Shape { public init() {}; public func path(in rect: CGRect) -> Path { Path() } }
public struct RoundedRectangle: Shape {
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {}
    public func path(in rect: CGRect) -> Path { Path() }
}

// MARK: - Styles and modifiers

public struct ButtonStyleConfiguration {
    public struct Label: View { public var body: Never { fatalError() } }
    public let label: Label
    public let isPressed: Bool
}
public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public protocol PrimitiveButtonStyle {}
public struct PlainButtonStyle: PrimitiveButtonStyle { public init() {} }
public struct BorderlessButtonStyle: PrimitiveButtonStyle { public init() {} }
extension PrimitiveButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { .init() } }
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { .init() } }

public protocol PickerStyle {}
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
public struct MenuPickerStyle: PickerStyle { public init() {} }
extension PickerStyle where Self == SegmentedPickerStyle { public static var segmented: SegmentedPickerStyle { .init() } }
extension PickerStyle where Self == MenuPickerStyle { public static var menu: MenuPickerStyle { .init() } }

public struct _ViewModifier_Content: View { public var body: Never { fatalError() } }
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifier_Content
    @ViewBuilder func body(content: Content) -> Body
}

extension View {
    public func modifier<M: ViewModifier>(_ m: M) -> _Mod { _Mod() }
    public func font(_ f: Font?) -> _Mod { _Mod() }
    public func fontWeight(_ w: Font.Weight?) -> _Mod { _Mod() }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> _Mod { _Mod() }
    public func foregroundColor(_ c: Color?) -> _Mod { _Mod() }
    public func tint(_ c: Color?) -> _Mod { _Mod() }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> _Mod { _Mod() }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                      minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                      alignment: Alignment = .center) -> _Mod { _Mod() }
    public func padding(_ length: CGFloat? = nil) -> _Mod { _Mod() }
    public func padding(_ edges: Edge.Set, _ length: CGFloat? = nil) -> _Mod { _Mod() }
    public func padding(_ insets: EdgeInsets) -> _Mod { _Mod() }
    public func background<V: View>(_ v: V, alignment: Alignment = .center) -> _Mod { _Mod() }
    public func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> _Mod { _Mod() }
    public func overlay<V: View>(_ v: V, alignment: Alignment = .center) -> _Mod { _Mod() }
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> _Mod { _Mod() }
    public func opacity(_ o: Double) -> _Mod { _Mod() }
    public func lineLimit(_ n: Int?) -> _Mod { _Mod() }
    public func minimumScaleFactor(_ f: CGFloat) -> _Mod { _Mod() }
    public func multilineTextAlignment(_ a: TextAlignment) -> _Mod { _Mod() }
    public func fixedSize() -> _Mod { _Mod() }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> _Mod { _Mod() }
    public func tracking(_ t: CGFloat) -> _Mod { _Mod() }
    public func kerning(_ t: CGFloat) -> _Mod { _Mod() }
    public func textCase(_ c: TextCase?) -> _Mod { _Mod() }
    public func lineSpacing(_ s: CGFloat) -> _Mod { _Mod() }
    public func contentShape<S: Shape>(_ s: S) -> _Mod { _Mod() }
    public func clipShape<S: Shape>(_ s: S) -> _Mod { _Mod() }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> _Mod { _Mod() }
    public func scaleEffect(_ s: CGFloat) -> _Mod { _Mod() }
    public func rotationEffect(_ a: Angle) -> _Mod { _Mod() }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> _Mod { _Mod() }
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> _Mod { _Mod() }
    public func position(_ p: CGPoint) -> _Mod { _Mod() }
    public func allowsHitTesting(_ b: Bool) -> _Mod { _Mod() }
    public func ignoresSafeArea() -> _Mod { _Mod() }
    public func animation<V: Equatable>(_ a: Animation?, value: V) -> _Mod { _Mod() }
    public func transition(_ t: AnyTransition) -> _Mod { _Mod() }
    public func buttonStyle<S: ButtonStyle>(_ s: S) -> _Mod { _Mod() }
    public func buttonStyle<S: PrimitiveButtonStyle>(_ s: S) -> _Mod { _Mod() }
    public func pickerStyle<S: PickerStyle>(_ s: S) -> _Mod { _Mod() }
    public func disabled(_ d: Bool) -> _Mod { _Mod() }
    public func tag<V: Hashable>(_ v: V) -> _Mod { _Mod() }
    public func id<V: Hashable>(_ v: V) -> _Mod { _Mod() }
    public func onAppear(perform: (() -> Void)? = nil) -> _Mod { _Mod() }
    public func onDisappear(perform: (() -> Void)? = nil) -> _Mod { _Mod() }
    public func onChange<V: Equatable>(of v: V, perform: @escaping (V) -> Void) -> _Mod { _Mod() }
    public func onTapGesture(perform: @escaping () -> Void) -> _Mod { _Mod() }
    public func listRowBackground<V: View>(_ v: V?) -> _Mod { _Mod() }
    public func listRowInsets(_ i: EdgeInsets?) -> _Mod { _Mod() }
    public func listRowSeparator(_ v: Visibility) -> _Mod { _Mod() }
    public func scrollContentBackground(_ v: Visibility) -> _Mod { _Mod() }
    public func navigationTitle(_ t: String) -> _Mod { _Mod() }
    public func navigationBarTitleDisplayMode(_ m: NavigationBarItem.TitleDisplayMode) -> _Mod { _Mod() }
    public func navigationDestination<D: Hashable, C: View>(for d: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> _Mod { _Mod() }
    public func toolbar<C: View>(@ViewBuilder content: () -> C) -> _Mod { _Mod() }
    public func toolbar(_ v: Visibility, for p: ToolbarPlacement...) -> _Mod { _Mod() }
    public func sheet<C: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> _Mod { _Mod() }
    public func fullScreenCover<C: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> _Mod { _Mod() }
    public func confirmationDialog<A: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                            @ViewBuilder actions: () -> A) -> _Mod { _Mod() }
    public func alert<A: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> _Mod { _Mod() }
    public func environmentObject<O: ObservableObject>(_ o: O) -> _Mod { _Mod() }
    public func environment<V>(_ kp: WritableKeyPath<EnvironmentValues, V>, _ v: V) -> _Mod { _Mod() }
    public func preferredColorScheme(_ s: ColorScheme?) -> _Mod { _Mod() }
    public func autocorrectionDisabled(_ d: Bool = true) -> _Mod { _Mod() }
    public func textInputAutocapitalization(_ a: TextInputAutocapitalization?) -> _Mod { _Mod() }
    public func keyboardType(_ k: Int) -> _Mod { _Mod() }
}
public enum ColorScheme: Hashable { case light, dark }

extension MutableCollection where Self: RangeReplaceableCollection {
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {}
}

// MARK: - Timers, App and Scene

public struct TimerPublisher {
    public func autoconnect() -> TimerPublisher { self }
}
extension Timer {
    public static func publish(every: TimeInterval, on: RunLoop, in mode: RunLoop.Mode) -> TimerPublisher { TimerPublisher() }
}
extension View {
    public func onReceive(_ p: TimerPublisher, perform: @escaping (Date) -> Void) -> _Mod { _Mod() }
}

public protocol Scene {}
public struct WindowGroup<C: View>: Scene {
    public init(@ViewBuilder content: () -> C) {}
}
extension Scene {
    public func onChange<V: Equatable>(of v: V, perform: @escaping (V) -> Void) -> some Scene { self }
}
@resultBuilder public struct SceneBuilder {
    public static func buildBlock<S: Scene>(_ s: S) -> S { s }
}
@MainActor public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()
}
extension App {
    public static func main() {}
}

// MARK: - More APIs used by the quick-game screens

public struct ContentTransition { public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition() } }
public struct GridItem {
    public enum Size { case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity), fixed(CGFloat), adaptive(minimum: CGFloat) }
    public init(_ size: Size, spacing: CGFloat? = nil, alignment: Alignment? = nil) {}
}
public struct LazyVGrid<C: View>: View {
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct Transaction {
    public init() {}
    public var disablesAnimations = false
    public var animation: Animation? = nil
}
public func withTransaction<R>(_ t: Transaction, _ body: () throws -> R) rethrows -> R { try body() }
public struct FillStyle { public init(eoFill: Bool = false, antialiased: Bool = true) {} }
extension AnyTransition {
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { AnyTransition() }
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { AnyTransition() }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { AnyTransition() }
    public static func push(from edge: Edge) -> AnyTransition { AnyTransition() }
}
extension Picker {
    public init(selection: Binding<T>, @ViewBuilder _ content: () -> C, @ViewBuilder label: () -> L) {}
}
extension View {
    public func contentTransition(_ t: ContentTransition) -> _Mod { _Mod() }
}
extension Shape {
    public func fill<S: ShapeStyle>(_ s: S, style: FillStyle) -> _Mod { _Mod() }
}
extension View {
    public func rotation3DEffect(_ a: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center,
                                 anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> _Mod { _Mod() }
}
extension Shape {
    public func stroke(style: StrokeStyle) -> _Mod { _Mod() }
    public func stroke(lineWidth: CGFloat = 1) -> _Mod { _Mod() }
}
extension View {
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> _Mod { _Mod() }
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint) -> _Mod { _Mod() }
}
public struct Form<C: View>: View {
    public init(@ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
public struct EditButton: View { public init() {}; public var body: Never { fatalError() } }
extension Binding: Sequence where Value: MutableCollection & RandomAccessCollection {
    public typealias Element = Binding<Value.Element>
    public typealias Iterator = IndexingIterator<Binding<Value>>
}
extension Binding: Collection where Value: MutableCollection & RandomAccessCollection {
    public typealias Index = Value.Index
    public var startIndex: Value.Index { wrappedValue.startIndex }
    public var endIndex: Value.Index { wrappedValue.endIndex }
    public func index(after i: Value.Index) -> Value.Index { wrappedValue.index(after: i) }
    public subscript(position: Value.Index) -> Binding<Value.Element> {
        Binding<Value.Element>(get: { self.wrappedValue[position] }, set: { _ in })
    }
}
extension Binding: BidirectionalCollection where Value: MutableCollection & RandomAccessCollection {
    public func index(before i: Value.Index) -> Value.Index { wrappedValue.index(before: i) }
}
extension Binding: RandomAccessCollection where Value: MutableCollection & RandomAccessCollection {}
extension Binding: Identifiable where Value: Identifiable {
    public var id: Value.ID { wrappedValue.id }
}
extension RangeReplaceableCollection where Self: MutableCollection {
    public mutating func remove(atOffsets offsets: IndexSet) {}
}
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
extension EnvironmentValues {
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { K.defaultValue }
        set {}
    }
}
extension View {
    public func navigationDestination<C: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> C) -> _Mod { _Mod() }
}
public enum DynamicTypeSize: Hashable { case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge }
extension View {
    public func dynamicTypeSize(_ s: DynamicTypeSize) -> _Mod { _Mod() }
}
public struct LazyVStack<C: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}
    public var body: Never { fatalError() }
}
extension View {
    public func mask<M: View>(_ m: M) -> _Mod { _Mod() }
    public func mask<M: View>(alignment: Alignment = .center, @ViewBuilder _ m: () -> M) -> _Mod { _Mod() }
}
public struct SafeAreaRegions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let all = SafeAreaRegions(rawValue: 1), container = SafeAreaRegions(rawValue: 2), keyboard = SafeAreaRegions(rawValue: 4)
}
extension View {
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> _Mod { _Mod() }
}
