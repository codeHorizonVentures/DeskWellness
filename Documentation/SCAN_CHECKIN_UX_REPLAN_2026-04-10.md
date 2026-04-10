# ResetMinute Scan Check-In UX Replan

Date: April 10, 2026

## Why this plan exists

Recent user feedback on the current camera check-in screen:

- users do not understand what this screen is trying to do
- users expect the silhouette to behave like a target frame
- users can remain in `SCANNING...` indefinitely without knowing whether they are too close, too far, off angle, or simply waiting for internal detection

This is a product and UX failure, not only a model-tuning issue.

## What the current screen is actually doing

The current screen is meant to run an optional front-camera posture-awareness check-in.

In the current implementation:

- the flow is not looking for simple face alignment with the on-screen outline
- the front check-in locks only when Vision detects `nose + left shoulder + right shoulder`
- after that lock appears, the app still requires `5` seconds of stable tracking before advancing
- if lock never stabilizes, the user can remain in `SCANNING...` with no bounded end state

Practical result:

- the visible cue says `fit yourself into this outline`
- the real system says `wait until hidden pose conditions are satisfied, then hold still`

That mismatch is why the flow feels broken.

## Product decision

The current repo direction remains correct:

- camera check-ins stay optional
- the main product remains quick desk resets and repeatable workday habit loops
- the camera flow should be an occasional awareness feature, not the hero experience

If the camera flow cannot become obviously understandable and finite, it should be further demoted rather than promoted.

## UX diagnosis

Top failures on the current screen:

1. The silhouette implies a direct success target, but it is only decorative guidance.
2. `SCANNING...` communicates activity without progress, criteria, or next step.
3. `LOCKED` is an internal system concept, not useful user language.
4. The flow has no bounded timeout, retry explanation, or visible non-camera escape path.
5. The screen feels like a biometric scanner instead of a calm wellness check-in.

## Redesigned interaction model

The redesigned optional check-in should use a simple step-based model:

1. prepare
2. align
3. hold
4. captured
5. result

This should replace the current scanner-style feeling.

### Entry point

- label the feature `Optional Check-In`
- keep `Start Quick Reset` as the primary action on home
- preserve a visible non-camera path at every stage

### Camera intro

Show a short explainer before the live camera state:

- `Camera is used only for this optional check-in.`
- `The check-in runs on your device.`
- `If you save a check-in, it is stored locally on your phone.`

The intro should also explain the physical setup:

- `Set your phone down before starting.`
- `Lean it against your monitor or place it on a stand.`
- `Step back until your head and shoulders are visible.`

This is important because the current flow effectively assumes a stable camera, but the product does not currently say that out loud.

Actions:

- `Continue`
- `Skip`

### Device setup guidance

Before live detection begins, the flow should teach the required setup instead of assuming it.

Recommended setup instruction:

- `Place your phone on a desk, stand, or other stable surface`
- `Do not hold the phone in your hand during the check-in`
- `Step back and face the camera naturally`

Recommended visual treatment:

- a short looped animation showing the phone being placed against a monitor, on a stand, or on a desk surface
- a simple transition from `holding phone` to `phone placed` to `step back into view`
- one static fallback illustration if animation is unavailable

This setup cue should appear before the first front-camera attempt and again inside retry states if the app fails to get a stable check-in.

### Live check-in states

#### 1. Not ready

Goal:
- explain what is missing in plain language

Examples:
- `Move back until your upper body is visible`
- `Face the camera with shoulders in view`

UI behavior:

- neutral guidance card
- muted silhouette
- no progress language

#### 2. Aligned

Goal:
- confirm that detection is good enough to start the hold phase

Examples:
- `Aligned`
- `Ready to hold`

UI behavior:

- subtle success accent on outline
- replace `SCANNING...` with a positive readiness state

#### 3. Holding

Goal:
- show that the app is waiting for stability, not still searching

Examples:
- `Hold still for 3 seconds`

UI behavior:

- visible countdown or progress ring
- optional haptic/audio confirmation when hold begins

#### 4. Captured

Goal:
- make success unmistakable

Examples:
- `Check-In Saved`
- `Done`

UI behavior:

- brief success state
- immediate transition to result

#### 5. Timeout / Try again

Goal:
- prevent endless scanning

Examples:
- `We could not get a clear check-in this time`
- `Try again or start your reset without it`

UI behavior:

- bounded attempt window
- primary `Try Again`
- secondary `Skip Check-In`

## Visual direction

The screen should move away from:

- scanner language
- HUD-like chips
- ambiguous silhouette-as-target behavior
- intense biometric aesthetics

The screen should move toward:

- calm wellness check-in language
- softer accents
- clearer state transitions
- obvious success and failure outcomes

Suggested state naming:

- `Looking for your upper body`
- `Aligned`
- `Hold still`
- `Done`
- `Try again`

Avoid:

- `SCANNING...`
- `LOCKED`
- `score-heavy` or `correction-heavy` framing

## Minimum implementation path

This should be treated as a finite UX repair first, not a full posture-engine rewrite.

Smallest viable change set:

1. Keep the existing detection engine and result model.
2. Add a pre-scan setup step that explicitly tells the user to place the phone on a stable surface instead of holding it.
3. Add explicit front-scan UI states instead of a single generic scanning state.
4. Replace the current top-chip text with user-facing state text.
5. Add a visible hold countdown during the stability phase.
6. Add a bounded attempt timeout for front scanning.
7. Add a clear skip path back to the reset flow.
8. Reduce hold duration if testing shows `5` seconds is too demanding for an optional check-in.

## Acceptance criteria

The redesigned flow is acceptable only if all of the following are true:

1. Users can describe what the screen is trying to do without guessing.
2. The app explicitly tells the user to place the phone on a stable surface and not hold it during the check-in.
3. The app shows distinct states for detecting, aligned, holding, captured, and failure.
4. The user sees visible progress during the hold phase.
5. The flow cannot remain in a single indefinite `SCANNING...` state.
6. The user can always skip the check-in and continue with the main reset loop.
7. Copy stays inside a general-wellness boundary and does not imply diagnosis or treatment.
8. Camera and local-storage language matches actual app behavior.

## Validation plan

High-value validation for this redesign:

- one state-transition test covering lock, hold duration, and timeout behavior
- one UI test covering the optional check-in path from launch to either result or retry/skip
- manual verification that the camera intro and save behavior match real local-storage behavior
- manual review that the copy stays in optional-awareness language, not clinical or corrective framing

## Ownership routing

This flow should be routed through:

- Product Lead for scope and acceptance criteria
- Product Designer and Visual UI Designer for flow and states
- iOS Tech Lead and Core iOS for implementation
- Security and Privacy for camera and storage wording
- QA for state and timeout regression coverage

## Recommended next build ticket

`Redesign optional check-in screen to show explicit camera states, visible hold progress, bounded timeout, and skip path while preserving wellness-safe copy and privacy-accurate camera language.`
