# Onboarding & Settings Validation Upgrades — Design
**Date:** 2026-04-09  
**Status:** Draft (pending approval)  
**Scope:** Onboarding polish (validation, formatting, skip/enter rules, name sanitization, optional keys), Edit Contact sheet parity, and Settings save-button state/affordance.

## Goals
- Enforce clear validation/formatting for name, email, phone, location; sanitize names; consistent behavior in onboarding and Edit Contact sheet.
- Skip buttons only on optional steps; Enter advances only when valid and never triggers Skip.
- Improve settings Save UX: enable only on change, show green “Saved” state after success, maintain clean divider/spacing.

## Affected Surfaces
- Onboarding steps: Name, Contact (Email/Phone/Location), Claude Key, Tavily Key.
- Edit Contact Info sheet (`EditBasicsView`).
- Settings screen save button (same interaction pattern wherever Save applies).

## Rules & Behaviors
### Name (Onboarding Name step + Edit Contact)
- Sanitization: trim leading/trailing whitespace on both fields; collapse internal whitespace to single spaces. Merged full name is `"<first> <last>"` with exactly one space, trimmed ends.
- Validation: first name required (non-empty after trim/collapse). Last name optional but sanitized. Error if merged name empty.
- Enter/Next: only advances when valid. No Skip on this step.

### Email
- Normalize: trim whitespace, lowercase for storage/validation.
- Validation: RFC-5322-lite regex (common production-safe pattern). Inline error shown on blur or submit attempt. Disable primary CTA until valid.

### Phone
- Optional. Normalize: strip non-digits for validation; stored normalized digits. Validation: 7–15 digits. Inline error if invalid when non-empty.
- Formatting: apply lightweight mask for display (e.g., `(XXX) XXX-XXXX` when 10 digits; otherwise group digits with spaces) without altering stored normalized digits.

### Location
- Required on Contact step. Normalize: trim and collapse internal spaces.
- Validation: non-empty AND at least two tokens separated by space or comma (basic structure). Inline error if empty/ill-formed. Keep ready for future geocode hook; no external calls now.

### API Keys (Claude, Tavily)
- Optional steps retain Skip. Trim whitespace; validation is non-empty to enable Next when provided. Enter advances only when non-empty; otherwise stays put.

### Skip / Enter / Buttons
- Required steps (Name, Contact): no Skip. Enter advances only when valid; otherwise focuses field and shows errors. Primary button disabled until valid.
- Optional steps (Claude/Tavily): explicit Skip as secondary. Enter advances only when valid (non-empty key). Primary button disabled until valid.
- Inline errors: red caption text and tinted outline for invalid fields; remove when valid.

### Edit Contact Info Sheet (`EditBasicsView`)
- Apply the same sanitization/validation/formatting rules as onboarding for name, email, phone, location.
- Save disabled until all required fields valid and at least one field has changed from the persisted values.
- On Save success: sheet dismiss; stored values normalized (name collapsed/trimmed, email lowercased/trimmed, phone normalized digits or nil if empty, location trimmed/collapsed).

### Settings Save Button UX
- Default: disabled “Save” when no field changes.
- On edits: enable primary “Save”.
- After successful save: briefly show a green “Saved” confirmation (toast or inline message) and return the button to disabled/inactive state; it re-enables on the next edit. Keep divider/spacing intact.

## Error Messaging (inline)
- Name: “Enter your first name.” (or similar concise copy)
- Email: “Enter a valid email.”
- Phone: “Enter a valid phone number.” (only when non-empty and fails)
- Location: “Enter your city and region.”
- Keys: none beyond disable state; optional steps can be skipped.

## Accessibility & UX Notes
- Use `.submitLabel(.done)` or `.next` appropriately; hook submit to validation gate.
- Keep focus on the first invalid field on submit attempts.
- Maintain current layout spacing; only add small inline error text and outline color.

## Out of Scope
- No external geocoding or address suggestions.
- No backend verification of keys (Claude/Tavily) beyond non-empty.

## Acceptance Criteria
- Required steps have no Skip; Enter never triggers Skip.
- Name is stored as trimmed/collapsed with single separating space; no leading/trailing whitespace.
- Invalid email/phone/location block advance/save and show inline errors; phone optional but validated when present.
- Edit Contact sheet mirrors onboarding rules and blocks Save until valid + changed.
- Settings save button shows enabled only when changed, and shows green “Saved” (disabled) after success until the next edit.
