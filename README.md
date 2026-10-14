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
  - `Assets.xcassets` — App Icon (1024×1024) and accent color
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

The app opens **directly into the UIOnboarding welcome screen** (`RootView`).
Tapping "Continue" transitions to `ContentView` and records completion in the
`hasCompletedOnboarding` `UserDefaults` key. The toolbar button on `ContentView`
resets that key to replay the onboarding.

There is also a plain system launch screen (generated from
`INFOPLIST_KEY_UILaunchScreen_Generation`) that flashes briefly before SwiftUI
renders — the animated onboarding itself cannot be the OS-level launch screen.
