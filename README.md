# Currex — Currency Converter

A polished Flutter currency converter featuring glassmorphism UI, live exchange rates, and an Android home-screen widget.

## Features

### Core
- **Real-time conversion** between 20+ currencies via live API rates
- **Offline support** — cached rates are used automatically when the network is unavailable
- **Android home-screen widget** that displays the current rate and auto-updates

### UI & Theming
- **Light / Dark theme** with an animated sun ↔ moon toggle
- **Dual color palette** — bright frosted-glass cards in light mode, translucent overlays in dark mode
- **Glassmorphism design** — backdrop blur, semi-transparent fills, subtle borders
- **Animated gradient background** with floating color orbs
- **Smooth transitions** — swap animation, refresh spinner, skeleton loading states

### Productivity
- **Quick Rates** — configurable multiplier table; tap any row to use that amount
- **Favorites** — star currency pairs for one-tap access
- **Recents** — automatically tracked recent conversions
- **Amount History** — per-pair log of searched amounts, tap to restore
- **Responsive layout** — adapts padding and sizing for wider screens

## Screenshots

<!-- Add screenshots here -->
<!-- ![Light mode](docs/light.png) ![Dark mode](docs/dark.png) -->

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.0)
- Android Studio or VS Code with Flutter extension
- Android device / emulator (API 21+) or iOS simulator

### Setup

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build release APK
flutter build apk
```

### Adding the Home-Screen Widget (Android)

1. Run the app at least once so widget data is initialised.
2. Long-press your Android home screen → **Widgets**.
3. Find **Currex** and drag it to your home screen.

## Architecture

```
lib/
  main.dart                  – App entry, theme management, route setup
  home_screen.dart           – Main conversion UI & all widgets
  app_colors.dart            – Centralised color system & dual AppPalette
  format_utils.dart          – Shared compact number formatters
  currency_service.dart      – HTTP client for exchange rates + cache
  favorites_service.dart     – Persistent favorite pairs (SharedPreferences)
  amount_history_service.dart – Per-pair amount history storage
  quick_rates_service.dart   – Configurable quick-rate multipliers
  widget_service.dart        – Pushes data to the Android home-screen widget

android/app/src/main/
  kotlin/…/
    MainActivity.kt              – Flutter activity
    CurrencyWidgetReceiver.kt    – Native widget provider
  res/layout/
    currency_widget_layout.xml   – Widget UI layout
  res/xml/
    currency_widget_info.xml     – Widget metadata
```

## API

Uses [exchangerate.host](https://exchangerate.host) for rates (free, no key required for basic usage). Swap the URL in `currency_service.dart` if you prefer another provider.

## License

This project is provided as-is for personal and educational use.
