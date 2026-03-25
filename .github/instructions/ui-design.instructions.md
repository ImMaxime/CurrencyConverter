---
description: "Use when editing Flutter UI files, screens, widgets, layouts, themes, or any visual component. Covers Material 3 theming, responsive patterns, spacing, color, and accessibility conventions."
applyTo: "lib/**/*.dart"
---

# UI & Design Standards

## Theming
- Always use `Theme.of(context)` for colors and text styles — never hardcode
- Reference `ColorScheme` roles: `primary`, `onPrimary`, `surface`, `onSurface`, `error`
- Use `textTheme` scale: `displayLarge` → `bodySmall` — no raw `TextStyle` with fixed sizes

## Spacing
- Follow an 8px grid: 4, 8, 12, 16, 24, 32, 48, 64
- Use `EdgeInsets.all(16)` or `EdgeInsets.symmetric()` — not arbitrary values
- Wrap root content in `SafeArea` and apply consistent page padding (16–24px)

## Responsive
- Use `LayoutBuilder` or `MediaQuery` for adaptive layouts
- Compact: single column, bottom navigation
- Medium: rail navigation, wider content
- Expanded: sidebar + content, multi-pane

## Components
- Keep `build()` methods concise — extract sub-widgets as private methods
- Name widgets semantically: `CurrencyInputCard`, `RateDisplay`, `ConversionResult`
- Provide `Semantics` labels for screen readers on all interactive widgets
- Use `const` constructors wherever possible for performance

## States
- Every data-driven widget must handle: loading, loaded, error, and empty
- Use skeleton/shimmer for loading — avoid bare `CircularProgressIndicator`
- Error states should be inline with recovery actions, not just text

## Animation
- Prefer implicit animations: `AnimatedContainer`, `AnimatedOpacity`
- Default curve: `Curves.easeOutCubic`, duration: 300ms
- Use `Hero` for cross-screen transitions on key elements
