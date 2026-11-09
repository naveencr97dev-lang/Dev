import XCTest
@testable import AuctionEngine

/// Enforces the layer rules in docs/ARCHITECTURE.md.
final class ArchitectureTests: XCTestCase {
    static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources")

    func swiftFiles(_ folder: String) -> [URL] {
        let dir = Self.sources.appendingPathComponent(folder)
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        return (e?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
    }

    /// L0/L1 (engine) never depends on UI frameworks.
    func testEngineHasNoUIDependency() throws {
        let files = swiftFiles("Engine")
        XCTAssertGreaterThan(files.count, 10)
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
            for ui in ["import SwiftUI", "import UIKit", "import Combine", "import Charts"] {
                XCTAssertFalse(text.contains(ui), "\(f.lastPathComponent) imports a UI framework (\(ui))")
            }
        }
    }

    /// L4 (views) never mutates the career directly: actions go through the store (L3).
    func testViewsDoNotMutateTheCareer() throws {
        for f in swiftFiles("Views") {
            let text = try String(contentsOf: f, encoding: .utf8)
            XCTAssertFalse(text.contains("mutateCareer"), "\(f.lastPathComponent) mutates the career; call a store action")
            XCTAssertFalse(text.range(of: #"store\.career\??\.[a-zA-Z]+\s*=[^=]"#, options: .regularExpression) != nil,
                           "\(f.lastPathComponent) assigns into the career")
        }
    }

    /// L0 save format: every schema version has a migration to the next.
    func testEverySchemaVersionHasAMigration() {
        for v in 1..<Career.currentSchema {
            XCTAssertNotNil(CareerSave.migrations[v], "no migration from schema \(v) to \(v + 1)")
        }
    }
}
