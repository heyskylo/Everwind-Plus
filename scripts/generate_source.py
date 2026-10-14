#!/usr/bin/env python3
"""Generate an AltStore / Feather compatible source JSON from built .ipa files.

The AltStore source format is also understood by Feather, SideStore, StikStore
and LiveContainer. We emit both the modern `versions` array and the legacy
top-level version fields, since stable AltStore still validates the latter.

The source can carry more than one app. Everwind is always emitted from
`--ipa`; pass `--mclce-ipa` to also list Minecraft LCE.
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


def build_app(
    *,
    ipa: pathlib.Path,
    base: str,
    ipa_filename: str,
    developer: str,
    subtitle: str,
    description: str,
    tint: str,
    category: str,
    fallback_bundle_id: str,
    fallback_name: str,
    fallback_version: str = "1.0",
    fallback_build: str = "1",
    fallback_min_os: str = "14.0",
    app_name: str | None = None,
) -> dict:
    """Build one AltStore `apps[]` entry from a built .ipa."""
    ipa = ipa.resolve()
    if not ipa.is_file():
        raise SystemExit(f"IPA not found: {ipa}")
    size = ipa.stat().st_size

    info = read_ipa_info(ipa)
    bundle_id = info.get("CFBundleIdentifier", fallback_bundle_id)
    version = info.get("CFBundleShortVersionString", fallback_version)
    build = info.get("CFBundleVersion", fallback_build)
    min_os = info.get("MinimumOSVersion", fallback_min_os)
    display = app_name or info.get("CFBundleDisplayName") or info.get("CFBundleName") or fallback_name

    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ipa_url = f"{base}/{ipa_filename}"
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

    return {
        "name": display,
        "bundleIdentifier": bundle_id,
        "developerName": developer,
        "subtitle": subtitle,
        "localizedDescription": description,
        "iconURL": icon_url,
        "tintColor": tint,
        "category": category,
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


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ipa", required=True, type=pathlib.Path,
                    help="Everwind .ipa (always emitted)")
    ap.add_argument("--mclce-ipa", type=pathlib.Path, default=None,
                    help="Optional Minecraft LCE .ipa to also list in the source")
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--base-url", required=True, help="Public URL of the repo root, e.g. https://repo.gayfeet.lol")
    ap.add_argument("--source-name", default="heyskylo")
    ap.add_argument("--identifier", default="com.heyskylo.everwind.source")
    ap.add_argument("--subtitle", default="Unsigned builds for AltStore & Feather")
    ap.add_argument("--description", default="Automated unsigned builds, signed on-device by AltStore, Feather, SideStore or LiveContainer.")
    ap.add_argument("--website", default="https://github.com/heyskylo/Everwind-Plus")
    ap.add_argument("--tint-color", default="#1C66FF")
    ap.add_argument("--developer", default="heyskylo")
    ap.add_argument("--category", default="other")
    ap.add_argument("--ipa-filename", default="Everwind.ipa")
    ap.add_argument("--app-name", default=None, help="Override the displayed Everwind name")
    ap.add_argument("--mclce-filename", default="Minecraft.LCE.ipa")
    ap.add_argument("--mclce-name", default="Minecraft LCE")
    ap.add_argument("--mclce-tint", default="#3C8527")
    ap.add_argument("--mclce-category", default="games")
    args = ap.parse_args()

    base = args.base_url.rstrip("/")

    apps = [
        build_app(
            ipa=args.ipa,
            base=base,
            ipa_filename=args.ipa_filename,
            developer=args.developer,
            subtitle="Minimal SwiftUI app with a UIOnboarding welcome screen.",
            description=(
                "Automated builds of Everwind, a minimal SwiftUI app with a "
                "UIOnboarding welcome screen. Signed on-device by AltStore, "
                "Feather, SideStore or LiveContainer."
            ),
            tint=args.tint_color,
            category=args.category,
            fallback_bundle_id="com.heyskylo.Everwind",
            fallback_name="Everwind",
            fallback_min_os="17.0",
            app_name=args.app_name,
        )
    ]

    if args.mclce_ipa is not None:
        apps.append(
            build_app(
                ipa=args.mclce_ipa,
                base=base,
                ipa_filename=args.mclce_filename,
                developer=args.developer,
                subtitle="Native iOS port of Minecraft: Legacy Console Edition (menu shell).",
                description=(
                    "Native iOS port of the Minecraft: Legacy Console Edition UI. "
                    "Unsigned - sign on-device with AltStore, Feather, SideStore or "
                    "LiveContainer. Controller required. Supply your own LCE assets "
                    "in the app's Documents folder; world gameplay is not implemented yet."
                ),
                tint=args.mclce_tint,
                category=args.mclce_category,
                fallback_bundle_id="com.legacy.mclce",
                fallback_name="Minecraft LCE",
                fallback_version="0.0.1",
                fallback_build="1",
                fallback_min_os="14.0",
                app_name=args.mclce_name,
            )
        )

    source = {
        "name": args.source_name,
        "identifier": args.identifier,
        "subtitle": args.subtitle,
        "description": args.description,
        "iconURL": f"{base}/icon.png",
        "website": args.website,
        "tintColor": args.tint_color,
        "featuredApps": [app["bundleIdentifier"] for app in apps],
        "apps": apps,
        "news": [],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8")
    summary = ", ".join(f"{a['bundleIdentifier']} {a['version']} ({a['versions'][0]['buildVersion']})" for a in apps)
    print(f"wrote {args.out}: {summary}")


if __name__ == "__main__":
    main()
