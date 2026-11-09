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
swiftc -parse-as-library -emit-module -module-name Charts -emit-module-path "$OUT/Charts.swiftmodule" \
  -I "$OUT" tools/typecheck/Charts.swift

S=ios/Sources
# Every app source file: the whole app must type-check.
FILES=( $(find "$S" -name '*.swift' | sort) )
swiftc -typecheck -parse-as-library -swift-version 5 -I "$OUT" "${FILES[@]}"
echo "typecheck OK (${#FILES[@]} files, the whole app)"
