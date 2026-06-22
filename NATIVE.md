# Native TDLib (tdjson) integration

Drachma talks **only** to real TDLib via Dart FFI (`lib/tdlib/td_bindings.dart`),
so each platform must ship the `tdjson` native library. There is no mock backend.

## 1. Credentials

```sh
cp lib/config/secrets_example.dart lib/config/secrets.dart
```

Fill in your `apiId` / `apiHash` from <https://my.telegram.org> → API tools.
`secrets.dart` is git-ignored. Until it's configured, the app launches straight
to a "尚未配置" notice (TDLib is never touched), which is handy for UI work.

## 2. Android

The FFI layer loads `libtdjson.so` by name, so the per-ABI libraries just need to
live under `android/app/src/main/jniLibs/<abi>/libtdjson.so` — the Gradle plugin
bundles them automatically.

```sh
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/<version>
./scripts/build-tdjson-android.sh           # arm64-v8a armeabi-v7a x86_64
```

(Building tdjson needs a cross-compiled OpenSSL + zlib per ABI — see the official
guide: <https://tdlib.github.io/td/build.html>. `minSdk` is pinned to 21.)

## 3. iOS

On Apple platforms the symbols are resolved from the app binary
(`DynamicLibrary.process()`), so `tdjson` must be linked into the Runner target.

1. Build (or download) `tdjson.xcframework` for device **and** simulator and place
   it at `ios/Frameworks/tdjson.xcframework`.
2. Add it to the Runner target (drag into Xcode → "Embed & Sign", or vendor it via
   the Podfile). `./scripts/build-tdjson-ios.sh` checks the framework is in place.
3. `cd ios && pod install` (needs CocoaPods: `brew install cocoapods`).

## 4. Run

```sh
flutter run            # pick an Android emulator or iOS simulator/device
```

The auth flow (phone → code → password) drives TDLib's `authorizationState`, and
the session persists in the per-account TDLib database under the app's support dir.

## Architecture notes

- `td_bindings.dart` binds the four stable `tdjson` C entry points.
- `td_client.dart` runs the blocking `td_receive` loop on a **dedicated isolate**
  (it re-opens the process-global library there) and posts events back to the main
  isolate, which correlates `@extra` responses, bootstraps `setTdlibParameters`
  per account, and broadcasts updates to a `Stream`. Multi-account "slots" persist
  in SharedPreferences, mirroring the Swift `TDLibClient`.
