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
  - `V86Assets/` — v86 runtime, BIOS, the Tiny Core Linux ISO, and the kernel/initramfs extracted from it (see below; binaries are downloaded, not committed)
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
- `scripts/iso-extract.py` — stdlib-only ISO9660 file extractor (used to pull the kernel/initramfs out of the ISO)

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
the app: SeaBIOS + VGA BIOS + a **Tiny Core Linux 11** image, running in a
full-screen `WKWebView`. The VM is shown in landscape, since the guest is a
desktop OS (the app restricts its orientation while the VM is open).

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

### Booting the kernel directly

The kernel is booted **directly** (v86's `bzimage` / `initrd` / `cmdline`
options) instead of letting the ISO's isolinux menu run. That menu waits 60
seconds (`TIMEOUT 600`) before picking a default, and offers no way to choose the
guest's screen resolution. Bootstrapping the kernel ourselves skips it and lets
us pass boot codes:

- `cde` — load the X/GUI extensions off the CD, which stays attached for exactly
  this purpose.
- `xvesa=1280x720x24` — the guest screen resolution.

`scripts/fetch-v86-assets.sh` pulls `vmlinuz` and `core.gz` out of the ISO with
`scripts/iso-extract.py`, a small stdlib-only ISO9660 reader — the CI runners are
macOS and have no `isoinfo`/`7z`/`bsdtar` to extract them with.

### Screen resolution

v86's VGA BIOS advertises only a small fixed set of VESA modes (`1280x720`,
`1600x900`, `1920x1080`, `1920x1200`, `2560x1440`, `2560x1600`, `320x200`).
Asking Xvesa for anything outside that list makes it silently substitute an
unrelated mode (`640x480`, `800x600`, …), so the guest must use a real one. The
widest aspect available is 16:9, and **1280x720x24** is the lightest of those.

An iPhone 14 panel is 19.5:9, which no VESA mode matches. The `aspectratio`
toolbar button switches between:

- **fill** (default) — stretch to the whole screen; and
- **exact** — keep 16:9 with thin bars on the sides.

### Interacting

- **Pointer:** v86 listens for `touchstart/move/end` on `window`, so a finger drag
  moves the guest pointer. v86 forwards pointer movement as *raw* CSS-pixel
  deltas, so `index.html` rescales them by the on-screen size of the canvas —
  otherwise the cursor drifts whenever the picture is scaled (which it always is
  on a phone screen).
- **Keyboard:** a hidden `<input>` is focused on tap, which makes iOS show its
  software keyboard; v86 reads keystrokes from `window` keydown/`input` events.
  A Bluetooth keyboard works too.
- **Controls:** the aspect-ratio toggle, ↻ (restart with a fresh boot) and ✕
  (close) sit in the top-right corner.
