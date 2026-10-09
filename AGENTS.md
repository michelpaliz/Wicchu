# Wicchu UI consistency

- Reuse `WicchuTheme`, `WicchuColors`, and existing shared components for UI changes. Do not invent per-screen or per-tab colors.
- Define any necessary new semantic color centrally in `lib/theme/wicchu_theme.dart`, with light and dark variants, only when the requested design requires it.
- Selected navigation, tabs, segmented controls, and filters use the shared brand accent and its corresponding foreground color. Use the global segmented-button theme rather than local color overrides.
- Keep layout, spacing, typography, icon sizes, and component shapes consistent between light and dark themes; vary semantic colors and surface treatments only.
- Preserve explicitly user-selected profile accents and established semantic status colors. These are intentional exceptions, not additional UI palettes.
