---
description: "Review a screen or widget for UI/UX quality — visual hierarchy, spacing, responsiveness, accessibility, and modern design patterns."
agent: "designer"
argument-hint: "Name the screen or widget file to review..."
---

Perform a thorough UI/UX design review on the specified screen or widget.

Evaluate each of these dimensions and provide a score (1–5) with specific findings:

## Checklist

1. **Visual Hierarchy** — Is there a clear focal point? Is information structured logically?
2. **Spacing & Rhythm** — Does it follow an 8px grid? Is whitespace consistent and generous?
3. **Typography** — Proper use of `TextTheme`? Clear heading/body distinction?
4. **Color & Contrast** — Semantic `ColorScheme` usage? WCAG AA contrast? Works in dark mode?
5. **Responsiveness** — Tested at compact/medium/expanded? No overflow? Adaptive layout?
6. **Interaction Design** — Proper feedback states (hover, press, focus, disabled)? Loading/error/empty handled?
7. **Accessibility** — Semantic labels? Touch targets ≥ 48px? No color-only meaning?
8. **Animation & Polish** — Meaningful transitions? Smooth and snappy (200–400ms)?
9. **Code Quality** — Clean widget tree? No deeply nested builders? Reusable extraction?

## Output

For each dimension:
- Score (1–5)
- What's working well
- Specific issues with line references
- Concrete fix recommendations with code snippets

End with a prioritized action list.
