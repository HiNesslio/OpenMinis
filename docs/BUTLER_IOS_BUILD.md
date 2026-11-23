# Build the Butler branch on your own iPhone (macOS/Xcode)

This guide fixes the three setup errors observed on the GitHub ZIP download: missing `ProviderCustomization.xcconfig`, missing FFmpeg/Rclone `.xcframework` products, and provisioning profiles for the upstream `com.openminis.app` entitlements.

## 1. Clone rather than use Download ZIP

```bash
cd ~/Downloads
git clone --recurse-submodules -b feat/ondevice-butler-foundation https://github.com/HiNesslio/OpenMinis.git OpenMinis-Butler
cd OpenMinis-Butler
```

GitHub ZIP archives do not supply the iSH and PRoot nested submodule source checkouts. They also do not contain locally built native frameworks. Please use a real clone rather than trying to manually copy placeholders into `deps/frameworks`.

## 2. Install native build prerequisites

Use a recent Xcode with the iOS SDK and Command Line Tools set to that Xcode. A physical ARM64 iPhone is strongly recommended for the first build.

```bash
xcode-select -p
xcodebuild -version
brew install ninja meson llvm libarchive pkg-config go
xcodebuild -downloadComponent MetalToolchain
```

Metal Toolchain is recommended for FFmpeg's complete hardware media filter set. If `brew` or Xcode are not installed, configure them first. The normal build also needs a working Python 3 interpreter.

## 3. Configure your own signing identity

**Personal Team / minimum-capability local build:**

```bash
python3 scripts/configure_ios_personal_dev.py --bundle-id com.example.minisbutlerdev
```

Replace `com.example.minisbutlerdev` with a unique reverse-DNS identifier you own. If you know your 10-character Apple Team ID, the script can set it on all targets:

```bash
python3 scripts/configure_ios_personal_dev.py --bundle-id com.example.minisbutlerdev --team ABCDE12345
```

The script:

- Copies `src/ios/Configs/ProviderCustomization.xcconfig.example` to the locally ignored `ProviderCustomization.xcconfig` if absent. Empty provider values are fine for API-key sign-in.
- Saves an ignored backup of `project.pbxproj`, then rewrites all app, extension, test target Bundle IDs to unique identifiers.
- Points app and extension signing settings at one generated **empty** `PersonalDev.entitlements` file. This avoids asking an ordinary Personal Team profile for App Group, iCloud, APNs, HealthKit, HomeKit, NFC, and WeatherKit capabilities it may not support.
- Leaves the original tracked `.entitlements` files untouched. This is an **opt-in local build variant**, not the signed production configuration.

If you omit `--team`, open Xcode → select project → Signing & Capabilities and choose **Automatically manage signing**, then your own Team on each applicable target (`Minis`, `MinisShare`, `MinisFileProvider`, `AgentWidgetExtension`, and test targets if building tests).

**Important limitation:** the stripped-entitlement variant is for validating the basic Today, Calendar, Reminders, Living Memory and chat experience. App Group sharing/Share Extension, iCloud sync, HealthKit, HomeKit, WeatherKit, remote push and other privileged features **will not work**. Do not distribute this variant as the fully featured application.

If you have a paid Developer Program membership and need those original features, create your own App IDs, unique App Group and iCloud container within your team, align the runtime identifiers (for example `SharedContainerStore.appGroupID`), and enable only capabilities permitted by your profile. Do **not** reuse `group.com.openminis.app` or `iCloud.com.openminis.app`.

## 4. Build required native frameworks

```bash
bash scripts/prepare_ios_device_deps.sh
```

This runs the actual build scripts in order: LAME → FFmpeg (produces `FFmpeg.xcframework` and six `libav*.xcframework` bundles) → iSH → Alpine rootfs → Rclone (produces `Rclone.xcframework`). It also checks the outputs exist. Build failures should be fixed at the first failing command; **do not** create empty `.xcframework` directories to silence Xcode.

## 5. Build and run on iPhone

```bash
open src/ios/Minis.xcodeproj
```

In Xcode, choose scheme **Minis**, select your connected iPhone as destination, verify **Automatically manage signing** and your Apple Team, then Build/Run. The FFmpeg/iSH scripts above build device ARM64 libraries; a Simulator run requires separately building `--simulator` versions and is not the recommended first test.

## 6. Undo local signing changes

```bash
python3 scripts/configure_ios_personal_dev.py --reset
```

This restores the original `project.pbxproj` from its local backup and removes only the generated `PersonalDev.entitlements`. The local provider customization is intentionally preserved. Keep any API keys and local development files out of Git.

## If a build still fails

- `No such file ProviderCustomization.xcconfig`: rerun step 3 from a fresh clone.
- `No XCFramework found`: complete step 4, verify the specific `.xcframework` directory, and keep the *first* dependency build error.
- `App Group Identifier ... unavailable` / `profile doesn't include capability`: inspect the **local** `CODE_SIGN_ENTITLEMENTS` for each target. It should point to `Configs/PersonalDev.entitlements` for the minimal Personal Team build; do not keep the official original Entitlements in that mode.
- `Signing requires a development team`: choose your Apple Team for every signing target or rerun with `--team`.
- `Swift compilation error`: only after the above three setup groups are resolved, report the first actual Swift diagnostic separately (especially files under `ButlerOnDevice.swift` or `ButlerLocalNotifications.swift`).

See [upstream BUILDING.md](../BUILDING.md) for the detailed device/simulator toolchain requirements.