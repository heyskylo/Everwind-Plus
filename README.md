# Everwind-Plus

A minimal SwiftUI iOS app with an Apple-Stocks-style onboarding welcome screen
powered by [UIOnboarding](https://github.com/lascic/UIOnboarding).

## What's here

- `Everwind/` — the app sources
  - `EverwindApp.swift` — `@main` SwiftUI entry point
  - `RootView.swift` — shows UIOnboarding as the launch screen, then `ContentView`
  - `ContentView.swift` — hello-world screen + "show onboarding again" button
  - `OnboardingView.swift` — bridges UIOnboarding's UIKit view controller into SwiftUI
  - `UIOnboardingHelper.swift` — builds the onboarding configuration (SF Symbols)
  - `V86WebView.swift` — WKWebView wrapper that boots the bundled x86 emulator
  - `V86Assets/` — v86 runtime, BIOS, and the Tiny Core Linux ISO (see below; binaries are downloaded, not committed)
  - `Assets.xcassets` — App Icon (1024×1024) and accent color
- `Everwind.xcodeproj` — Xcode project (Swift Package Manager dependency on UIOnboarding 2.0.5)
- `.github/workflows/ios.yml` — CI: builds for the iOS Simulator, packages an unsigned `.ipa`, and publishes it to the `latest` GitHub Release
- `site/` — the AltStore/Feather source served at <https://repo.gayfeet.lol>
  - `index.html` — landing page with "Add to AltStore / SideStore / Feather / LiveContainer" buttons
  - `icon.png` — app icon for the source listing
  - `apps.json` — the AltStore source document (regenerated on the VPS) 
- `scripts/generate_source.py` — builds `apps.json` from a compiled `.ipa`
- `scripts/vps-sync.sh` — VPS-side sync (installed as `/usr/local/bin/everwind-sync.sh`)
- `scripts/fetch-v86-assets.sh` — downloads the v86 emulator + Tiny Core ISO into `Everwind/V86Assets/`

## Sideload repo (self-hosted on the VPS)

- **Domain:** <https://repo.gayfeet.lol> → `192.95.29.190`, served by **Caddy** from `/srv/repo.gayfeet.lol`.
- **Source URL:** `https://repo.gayfeet.lol/apps.json`
- **App:** `https://repo.gayfeet.lol/Everwind.ipa`

CI publishes every successful build to the `latest` GitHub Release. A systemd
timer on the VPS (`everwind-sync.timer`, every 2 minutes) runs
`everwind-sync.service`, which:

1. fast-forwards a clone of this repo at `/opt/everwind`,
2. downloads the newest release IPA to `/var/lib/everwind/Everwind.ipa`,
3. regenerates `site/apps.json` from that IPA,
4. rsyncs `site/` + the IPA into `/srv/repo.gayfeet.lol`.

Trigger a sync manually:

```sh
sudo systemctl start everwind-sync.service
journalctl -u everwind-sync.service -n 30 --no-pager
```

## Requirements

- Xcode 15.4+ (iOS 17 deployment target)
- No signing required for the simulator build

## Build & run

First fetch the emulator assets (~22 MB, downloaded rather than committed):

```sh
./scripts/fetch-v86-assets.sh
```

Open `Everwind.xcodeproj` in Xcode, select the **Everwind** scheme, and run on a
simulator, or from the command line:

```sh
xcodebuild build \
  -project Everwind.xcodeproj \
  -scheme Everwind \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

To package an unsigned device build as an `.ipa`:

```sh
xcodebuild archive \
  -project Everwind.xcodeproj \
  -scheme Everwind \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Everwind.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

mkdir -p artifacts/Payload
cp -R build/Everwind.xcarchive/Products/Applications/Everwind.app artifacts/Payload/
( cd artifacts && zip -qr Everwind.ipa Payload )
```

## Onboarding

The app opens **directly into the UIOnboarding welcome screen** (`RootView`).
Tapping "Continue" transitions to `ContentView` and records completion in the
`hasCompletedOnboarding` `UserDefaults` key. The toolbar button on `ContentView`
resets that key to replay the onboarding.

There is also a plain system launch screen (generated from
`INFOPLIST_KEY_UILaunchScreen_Generation`) that flashes briefly before SwiftUI
renders — the animated onboarding itself cannot be the OS-level launch screen.

## Tiny Core Linux VM (x86 emulation, no JIT)

The "Boot Tiny Core Linux" button on `ContentView` boots a real x86 PC inside
the app: SeaBIOS + VGA BIOS + a **Tiny Core Linux 11 live ISO**, running in a
full-screen `WKWebView`.

This uses [v86](https://github.com/copy/v86), which translates guest x86 machine
code into WebAssembly at runtime. WebKit compiles that WebAssembly ahead of time
inside its own entitled process, so the app itself needs **no JIT entitlement** —
which is the whole reason it can be sideloaded and still run an emulator.

> Not QEMU. Upstream QEMU cannot be built as an in-process iOS library, and its
> TCG backend requires writable+executable memory (a JIT). Getting QEMU in here
> would mean building the UTM fork with `--enable-tcg-threaded-interpreter`, which
> is a multi-day cross-compiling project rather than a feature.

The emulator assets are **not committed** — `scripts/fetch-v86-assets.sh`
downloads them into `Everwind/V86Assets/`, and that directory is bundled into the
app as a folder reference. A `WKURLSchemeHandler` serves them over
`everwind://local/…`, because `WKWebView` blocks `fetch()` against `file://` URLs.
