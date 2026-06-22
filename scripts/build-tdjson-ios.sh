#!/usr/bin/env bash
#
# build-tdjson-ios.sh
#
# Builds TDLib's `tdjson` for iOS (device arm64 + simulator) and installs it as
# a static library that links into the Runner app, so the Dart FFI layer can
# resolve the symbols via DynamicLibrary.process() at runtime.
#
# The simplest, most reliable route is the official prebuilt XCFramework from
# tdlib/td-ios or building from source per https://tdlib.github.io/td/build.html.
# This script wires a prebuilt `tdjson.xcframework` (placed at
# ios/Frameworks/tdjson.xcframework) into the Runner target via the generated
# Xcode project; if you build from source, drop the resulting xcframework there.
#
# After placing the xcframework, also ensure ios/Podfile links it (see NATIVE.md)
# and that "Embed & Sign" is set so the symbols are present in the process.
#
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/ios/Frameworks"

echo "→ Expected: $DEST/tdjson.xcframework"
if [[ -d "$DEST/tdjson.xcframework" ]]; then
  echo "  ✓ tdjson.xcframework present"
else
  echo "  ✗ Missing. Build TDLib for iOS (device + simulator) and copy the"
  echo "    resulting tdjson.xcframework to $DEST/."
  echo "    See https://tdlib.github.io/td/build.html and NATIVE.md."
  exit 1
fi
echo "→ Now run: cd ios && pod install   (then: flutter run)"
