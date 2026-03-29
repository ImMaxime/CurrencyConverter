<p align="center">
  <img src="assets/icon/app_icon.png" alt="Currex logo" width="120" height="120" style="border-radius:24px" />
</p>

<h1 align="center">Currex</h1>

<p align="center">
  A polished Flutter currency converter with glassmorphism UI, live exchange rates, and an Android home-screen widget.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A5%203.0-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%E2%89%A5%203.0-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" alt="Platform">
  <img src="https://img.shields.io/badge/License-Personal%20%26%20Educational-blue" alt="License">
</p>

---

## Screenshots

<!-- Replace with actual screenshots -->
<!-- <p align="center">
  <img src="docs/screenshots/dark.png" width="250" alt="Dark mode" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/light.png" width="250" alt="Light mode" />
  &nbsp;&nbsp;
  <img src="docs/screenshots/widget.png" width="250" alt="Home-screen widget" />
</p> -->

> _Screenshots coming soon._

## Features

**Core**
- Real-time conversion between 20+ currencies via live API rates
- Offline support — cached rates are used automatically when the network is unavailable
- Android home-screen widget that displays the current rate and auto-updates

**UI & Theming**
- Light / Dark theme with an animated sun ↔ moon toggle
- Dual color palette — frosted-glass cards in light mode, translucent overlays in dark mode
- Glassmorphism design — backdrop blur, semi-transparent fills, subtle borders
- Animated gradient background with floating color orbs
- Smooth transitions — swap animation, refresh spinner, skeleton loading states

**Productivity**
- Quick Rates — configurable multiplier table; tap any row to use that amount
- Favorites — star currency pairs for one-tap access
- Recents — automatically tracked recent conversions
- Amount History — per-pair log of searched amounts, tap to restore
- Responsive layout — adapts padding and sizing for wider screens

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0
- Android Studio or VS Code with the Flutter extension
- Android device / emulator (API 21+) or iOS simulator

### Installation

```bash
git clone https://github.com/ImMaxime/CurrencyConverter.git
cd CurrencyConverter
flutter pub get
flutter run
```

### Build

```bash
# Android APK
flutter build apk

# iOS (requires macOS + Xcode)
flutter build ios
```

### Home-Screen Widget (Android)

1. Run the app at least once so widget data is initialised.
2. Long-press your Android home screen → **Widgets**.
3. Find **Currex** and drag it to your home screen.

## Architecture

```
lib/
├── main.dart                   App entry, theme management, route setup
├── home_screen.dart            Main conversion UI & all widgets
├── app_colors.dart             Centralised color system & dual AppPalette
├── format_utils.dart           Shared compact number formatters
├── currency_service.dart       HTTP client for exchange rates + cache
├── favorites_service.dart      Persistent favorite pairs (SharedPreferences)
├── amount_history_service.dart Per-pair amount history storage
├── quick_rates_service.dart    Configurable quick-rate multipliers
└── widget_service.dart         Pushes data to the Android home-screen widget

android/app/src/main/
├── kotlin/…/
│   ├── MainActivity.kt              Flutter activity
│   └── CurrencyWidgetReceiver.kt    Native widget provider
└── res/
    ├── layout/currency_widget_layout.xml   Widget UI layout
    └── xml/currency_widget_info.xml        Widget metadata
```

## Built With

- [Flutter](https://flutter.dev/) — Cross-platform UI framework
- [home_widget](https://pub.dev/packages/home_widget) — Android & iOS home-screen widgets
- [google_mobile_ads](https://pub.dev/packages/google_mobile_ads) — Banner ads via AdMob
- [shared_preferences](https://pub.dev/packages/shared_preferences) — Local key-value storage
- [exchangerate.host](https://exchangerate.host) — Free exchange rate API (no key required)

## Contributing

Contributions are welcome! If you have a bug fix or improvement:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is provided as-is for personal and educational use.
