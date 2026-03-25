# Currency Converter

A Flutter app with an **Android home screen widget** that displays live exchange rates.

## Features

- Convert between 20+ currencies with live rates
- Android home screen widget showing the current rate
- Widget auto-updates via the `home_widget` package

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.0)
- Android Studio or VS Code with Flutter extension
- An Android device/emulator (API 21+)

### Setup

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build release APK
flutter build apk
```

### Adding the Home Screen Widget

1. Run the app at least once so widget data is initialized.
2. Long-press your Android home screen → **Widgets**.
3. Find **Currency Converter** and drag it to your home screen.

## Project Structure

```
lib/
  main.dart              – App entry point
  home_screen.dart       – Main conversion UI
  currency_service.dart  – HTTP calls for exchange rates
  widget_service.dart    – Pushes data to the Android widget

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
