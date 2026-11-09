#!/usr/bin/env bash
# Type-checks the app's Swift on Linux against minimal SwiftUI/UIKit stand-ins.
# Usage (repo root):  tools/typecheck/run.sh
# Needs the Swift toolchain (CLAUDE.md: swift-6.0.3 in /opt/swift).
set -euo pipefail
cd "$(dirname "$0")/../.."
export PATH=/opt/swift/usr/bin:$PATH
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

swiftc -parse-as-library -emit-module -module-name SwiftUI -emit-module-path "$OUT/SwiftUI.swiftmodule" \
  tools/typecheck/SwiftUI.swift
swiftc -parse-as-library -emit-module -module-name UIKit -emit-module-path "$OUT/UIKit.swiftmodule" \
  tools/typecheck/UIKit.swift

S=ios/Sources
FILES=(
  $(find "$S/Engine" -name '*.swift')
  "$S"/Store/*.swift
  "$S"/Theme/*.swift
  "$S"/Views/Components.swift
  "$S"/Views/HomeView.swift
  "$S"/Views/SquadsView.swift
  "$S"/Views/SeasonView.swift
  $(find "$S/Views/Career" -name '*.swift')
  tools/typecheck/AppDecls.swift
)
swiftc -typecheck -parse-as-library -swift-version 5 -I "$OUT" "${FILES[@]}"
echo "typecheck OK (${#FILES[@]} files)"
