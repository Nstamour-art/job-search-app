# Liquid Glass Pass — TODO Completions
**Date:** 2026-04-08  
**Status:** Pending approval  
**Scope:** Replace the four Liquid Glass TODOs with a cohesive pass across Discover, Job Detail, Onboarding (skills chips), and Welcome CTA. Keep pre–iOS 26 fallbacks unchanged.

## Availability & Fallbacks
- Gate all glass with `#available(iOS 26, *)`; fallback keeps existing materials/buttons/capsules.
- Apply `.glassEffect` after layout/appearance modifiers; `.interactive()` only on tappable elements.
- Shapes: rect radius 12–14 for cards, capsule for chips.

## Global Patterns
- Use `GlassEffectContainer` to group related glass surfaces (header + priority, skills chips, Discover overlays).
- No glass on primary action buttons (apply/generate) to avoid over-glassing CTAs.
- No toolbar/search glass changes.

## View Treatments
### JobDetailView
- Wrap header + priority stack in `GlassEffectContainer(spacing: 12)`.
- Priority card: keep padding, then `.glassEffect(.regular, in: .rect(cornerRadius: 12))`, non-interactive.
- Header text block: optional cohesive touch — `.glassEffect(.regular, in: .rect(cornerRadius: 14))`, non-interactive.
- Buttons remain bordered/borderedProminent (no glass).

### WelcomeView
- Replace CTA with `.buttonStyle(.glassProminent)` on iOS 26+. Layout unchanged. Fallback keeps current colored rounded rect.

### OnboardingHelpers — SkillsChipsView
- Wrap `FlowLayout` in `GlassEffectContainer(spacing: 8)`.
- Each chip: keep padding/overlay, replace material background with `.glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)`; fallback keeps `.thinMaterial` + stroke.

### DiscoverView
- Lift progress/error out of `List` into overlay VStacks. Each card: `.glassEffect(.regular, in: .rect(cornerRadius: 12))`, non-interactive, top-centered with padding.
- Optionally add a subtle `GlassEffectContainer` background behind the list content area (not wrapping `List` itself) for cohesion; leave row cells unchanged for performance.
- No glass on toolbar or search field.

## Morphing / Transitions
- Skip `glassEffectID` for now; no morph animations needed between progress/error overlays.

## Testing / QA
- Verify conditional rendering on iOS 26+ vs earlier OS (visual sanity for both).
- Check tap targets for interactive chips and buttons remain unchanged.
- Ensure overlays don’t block list scroll/selection; use top alignment and ignore-safe-area only if needed.
