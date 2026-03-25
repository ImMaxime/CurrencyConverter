---
description: "Audit a screen or layout for responsive design issues — breakpoints, overflow, adaptive layout, and multi-device compatibility."
agent: "designer"
argument-hint: "Name the screen or file to audit for responsiveness..."
---

Audit the specified screen for responsive design quality.

## Steps

1. Read the target file and identify all layout widgets
2. Check for responsive patterns: `LayoutBuilder`, `MediaQuery`, `Expanded`, `Flexible`
3. Identify any hardcoded widths/heights that would break on different screens
4. Evaluate behavior at three breakpoints:
   - **Compact** (<600px): phones portrait
   - **Medium** (600–840px): tablets portrait, phones landscape
   - **Expanded** (>840px): tablets landscape, desktop
5. Check for overflow risks: long text, horizontal lists, fixed-width rows

## Output

- List of responsive issues found, with line numbers
- Recommended fix for each issue with code
- A summary of which breakpoints are properly handled vs missing
