#!/usr/bin/env python3
"""Prepare a *local* Xcode signing variant for a Personal Team.

This file does not alter tracked signing files in Git. It rewrites ONLY the
developer's local Xcode project file, leaving a reversible backup. Never run
against a production branch for App Store distribution.

Usage:
  python3 scripts/configure_ios_personal_dev.py \
      --bundle-id com.example.myminis --team YOUR10CHARTEAMID
  python3 scripts/configure_ios_personal_dev.py --reset
"""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IOS = ROOT / "src" / "ios"
PROJECT = IOS / "Minis.xcodeproj" / "project.pbxproj"
BACKUP = PROJECT.with_suffix(PROJECT.suffix + ".personal-dev.bak")
ENTITLEMENTS = IOS / "Configs" / "PersonalDev.entitlements"
CUSTOMIZATION = IOS / "Configs" / "ProviderCustomization.xcconfig"
CUSTOMIZATION_TEMPLATE = IOS / "Configs" / "ProviderCustomization.xcconfig.example"

# A normal provisioning profile can sign this *minimal* set.
# Some features from the upstream app will intentionally be unavailable.
EMPTY_ENTITLEMENTS = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
"""

BUNDLE_PATTERN = re.compile(r'(PRODUCT_BUNDLE_IDENTIFIER = )com\.openminis\.([A-Za-z0-9.]+)(;)')
ENTITLEMENTS_PATTERN = re.compile(
    r"CODE_SIGN_ENTITLEMENTS = "
    r"(?:Minis\.entitlements|ShareExtension/ShareExtension\.entitlements|"
    r"FileProvider/FileProvider\.entitlements|AgentWidget/AgentWidget\.entitlements);"
)


def configure(bundle_id: str, team: str | None) -> None:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,}", bundle_id):
        raise SystemExit("Invalid bundle id. Example: com.example.minisdev (must be unique).")
    if team is not None and not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise SystemExit("Team ID must be a 10-character Apple Developer Team ID.")

    if not PROJECT.exists() or not CUSTOMIZATION_TEMPLATE.exists():
        raise SystemExit("Missing project or xcconfig template. Run from the checked-out OpenMinis repository.")

    # The original stays available even across repeated invocations.
    if not BACKUP.exists():
        shutil.copy2(PROJECT, BACKUP)
    original = BACKUP.read_text(encoding="utf-8")

    def replace_bundle(m: re.Match[str]) -> str:
        suffix = m.group(2)
        if suffix == "app":
            assigned = bundle_id
        elif suffix.startswith("app."):
            assigned = bundle_id + suffix[len("app"):]
        else:
            assigned = bundle_id + "." + suffix
        return m.group(1) + assigned + m.group(3)

    changed, bundle_count = BUNDLE_PATTERN.subn(replace_bundle, original)
    if bundle_count < 8:
        raise SystemExit(
            "Unexpected Xcode bundle-ID layout. No changes written. "
            "This script supports the upstream com.openminis.* template only."
        )

    changed, entitlement_count = ENTITLEMENTS_PATTERN.subn(
        "CODE_SIGN_ENTITLEMENTS = Configs/PersonalDev.entitlements;", changed
    )
    if entitlement_count != 8:
        raise SystemExit(
            f"Expected eight app/extension entitlement settings; found {entitlement_count}. "
            "No changes written. Please inspect project.pbxproj."
        )

    if team:
        changed, count = re.subn(
            r'DEVELOPMENT_TEAM = "";',
            f"DEVELOPMENT_TEAM = {team};",
            changed
        )
        if count < 8:
            raise SystemExit(
                f"Expected several unassigned development teams, found {count}. "
                "No changes written."
            )

    ENTITLEMENTS.parent.mkdir(parents=True, exist_ok=True)
    ENTITLEMENTS.write_text(EMPTY_ENTITLEMENTS, encoding="utf-8")
    if not CUSTOMIZATION.exists():
        shutil.copy2(CUSTOMIZATION_TEMPLATE, CUSTOMIZATION)
        print("Created local ProviderCustomization.xcconfig from .example")
    else:
        print("Kept existing ProviderCustomization.xcconfig unchanged")

    PROJECT.write_text(changed, encoding="utf-8")
    print(f"Configured {bundle_count} bundle-ID settings and {entitlement_count} signing settings.")
    print(f"Base app bundle identifier: {bundle_id}")
    print(f"Apple Team: {team or 'select your own Team in Xcode for each target'}")
    print("All advanced entitlements are disabled in this LOCAL personal signing variant.")
    print("Unavailable: App Group sharing, CloudKit, APNs, HealthKit, HomeKit, NFC, WeatherKit.")
    print("The basic Today/Calendar/Reminders/Living Memory path can still be tested.")
    print("Original Xcode project backup:", BACKUP)
    print("Next: bash scripts/prepare_ios_device_deps.sh; then open src/ios/Minis.xcodeproj")


def reset() -> None:
    if not BACKUP.exists():
        raise SystemExit("No local signing backup found; nothing to restore.")
    shutil.copy2(BACKUP, PROJECT)
    BACKUP.unlink()
    if ENTITLEMENTS.exists():
        ENTITLEMENTS.unlink()
    print("Restored original Xcode project settings. Your customization xcconfig was preserved.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Opt-in local Personal Team signing setup")
    parser.add_argument("--bundle-id", help="Unique reverse-DNS app ID, e.g. com.example.minisdev")
    parser.add_argument("--team", help="Optional 10-character Apple Developer Team ID")
    parser.add_argument("--reset", action="store_true", help="Restore the original Xcode project")
    args = parser.parse_args()

    if args.reset:
        reset()
        return
    if not args.bundle_id:
        parser.error("--bundle-id is required unless --reset is given")
    configure(args.bundle_id, args.team)


if __name__ == "__main__":
    main()
