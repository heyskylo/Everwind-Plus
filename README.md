# Everwind-Plus

A minimal SwiftUI iOS app with an Apple-Stocks-style onboarding welcome screen
powered by [UIOnboarding](https://github.com/lascic/UIOnboarding).

## What's here

- `Everwind/` — the app sources
  - `EverwindApp.swift` — `@main` SwiftUI entry point
  - `ContentView.swift` — hello-world screen + "show onboarding again" button
  - `OnboardingView.swift` — bridges UIOnboarding's UIKit view controller into SwiftUI
  - `UIOnboardingHelper.swift` — builds the onboarding configuration (SF Symbols, no image assets required)
- `Everwind.xcodeproj` — Xcode project (Swift Package Manager dependency on UIOnboarding 2.0.5)
- `.github/workflows/ios.yml` — CI: builds for the iOS Simulator and packages an unsigned `.ipa`

## Requirements

- Xcode 15.4+ (iOS 17 deployment target)
- No signing required for the simulator build

## Build & run

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

The welcome screen is shown once on first launch (tracked with the
`hasCompletedOnboarding` `UserDefaults` key) and can be re-opened from the
toolbar. It is **not** the system launch screen — the launch screen is generated
from `INFOPLIST_KEY_UILaunchScreen_Generation`.
