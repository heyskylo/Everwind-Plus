#!/usr/bin/env python3
"""Generate an AltStore / Feather compatible source JSON from a built .ipa.

The AltStore source format is also understood by Feather, SideStore, StikStore
and LiveContainer. We emit both the modern `versions` array and the legacy
top-level version fields, since stable AltStore still validates the latter.
"""
from __future__ import annotations

import argparse
import datetime
import json
import pathlib
import plistlib
import zipfile


def read_ipa_info(ipa: pathlib.Path) -> dict:
    with zipfile.ZipFile(ipa) as zf:
        plist_name = next(
            name
            for name in zf.namelist()
            if name.startswith("Payload/") and name.endswith(".app/Info.plist")
        )
        with zf.open(plist_name) as fh:
            return plistlib.load(fh)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ipa", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--base-url", required=True, help="Public URL of the repo root, e.g. https://repo.gayfeet.lol")
    ap.add_argument("--source-name", default="Everwind")
    ap.add_argument("--identifier", default="com.heyskylo.everwind.source")
    ap.add_argument("--subtitle", default="Unsigned Everwind builds for AltStore & Feather")
    ap.add_argument("--description", default="Automated builds of Everwind, a minimal SwiftUI app with a UIOnboarding welcome screen. Signed on-device by AltStore, Feather, SideStore or LiveContainer.")
    ap.add_argument("--website", default="https://github.com/heyskylo/Everwind-Plus")
    ap.add_argument("--tint-color", default="#1C66FF")
    ap.add_argument("--developer", default="heyskylo")
    ap.add_argument("--category", default="other")
    ap.add_argument("--ipa-filename", default="Everwind.ipa")
    ap.add_argument("--app-name", default=None, help="Override the displayed app name")
    args = ap.parse_args()

    base = args.base_url.rstrip("/")
    ipa = args.ipa.resolve()
    if not ipa.is_file():
        raise SystemExit(f"IPA not found: {ipa}")
    size = ipa.stat().st_size

    info = read_ipa_info(ipa)
    bundle_id = info.get("CFBundleIdentifier", "com.heyskylo.Everwind")
    version = info.get("CFBundleShortVersionString", "1.0")
    build = info.get("CFBundleVersion", "1")
    min_os = info.get("MinimumOSVersion", "17.0")
    display = args.app_name or info.get("CFBundleDisplayName") or info.get("CFBundleName") or "Everwind"

    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ipa_url = f"{base}/{args.ipa_filename}"
    icon_url = f"{base}/icon.png"

    version_entry = {
        "version": version,
        "buildVersion": str(build),
        "date": date,
        "localizedDescription": f"Automated build {version} ({build}).",
        "downloadURL": ipa_url,
        "size": size,
        "minOSVersion": min_os,
    }

    app = {
        "name": display,
        "bundleIdentifier": bundle_id,
        "developerName": args.developer,
        "subtitle": "Minimal SwiftUI app with a UIOnboarding welcome screen.",
        "localizedDescription": args.description,
        "iconURL": icon_url,
        "tintColor": args.tint_color,
        "category": args.category,
        "screenshots": [],
        "appPermissions": {},
        "versions": [version_entry],
        # Legacy fields still required by stable AltStore for validation.
        "version": version,
        "versionDate": date,
        "versionDescription": version_entry["localizedDescription"],
        "downloadURL": ipa_url,
        "size": size,
    }

    source = {
        "name": args.source_name,
        "identifier": args.identifier,
        "subtitle": args.subtitle,
        "description": args.description,
        "iconURL": icon_url,
        "website": args.website,
        "tintColor": args.tint_color,
        "featuredApps": [bundle_id],
        "apps": [app],
        "news": [],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.out} ({size} bytes, {bundle_id} {version} ({build}), minOS {min_os})")


if __name__ == "__main__":
    main()
