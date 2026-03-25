---
description: "Design and implement a new Flutter widget or screen with modern aesthetics, responsive layout, accessibility, and proper state handling."
agent: "designer"
argument-hint: "Describe the component to design (e.g., 'settings screen with theme toggle')..."
---

Design and build a new Flutter component following best practices.

## Process

1. **Requirements** — Parse the user's description into concrete UI requirements
2. **Component Tree** — Plan the widget hierarchy before writing code
3. **States** — Identify all states: default, loading, error, empty, success
4. **Responsive** — Plan layout for compact, medium, and expanded breakpoints
5. **Implement** — Write clean, production-quality Flutter code:
   - Use `Theme.of(context)` for all colors and text styles
   - Follow 8px spacing grid
   - Add `Semantics` labels for accessibility
   - Include smooth implicit animations
   - Support both light and dark themes
6. **Polish** — Add micro-interactions, transitions, and edge case handling

## Output

- Complete widget code, ready to drop into the project
- Usage example showing how to integrate it
- Brief design rationale for key visual decisions
