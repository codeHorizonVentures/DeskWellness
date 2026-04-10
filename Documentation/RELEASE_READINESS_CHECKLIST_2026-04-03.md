# ResetMinute Release Readiness Checklist

Date: April 3, 2026

## Purpose

This checklist defines the minimum release gate for the first ResetMinute MVP.

It is intentionally narrow. The goal is to ship an iPhone-first general-wellness product for desk workers without drifting into medical-device positioning, privacy mismatches, or avoidable App Review failures.

## Release intent

The release is ready only if all of these remain true:

- the app is positioned as a general-wellness desk reset product
- posture is optional and secondary
- privacy text matches real on-device behavior
- the core reset loop works on real devices
- no certification-dependent claims are present anywhere customer-facing

## Product boundary gate

Ship only if customer-facing copy avoids:

- diagnosis language
- treatment, therapy, rehabilitation, or prevention claims
- guaranteed pain-relief claims
- clinical validation or clinical-accuracy claims
- clinic or medical-program framing

Check these places before release:

- in-app onboarding and empty states
- reminder and reset flow copy
- optional posture check-in copy
- paywall or upgrade messaging if present
- App Store metadata and screenshots
- website, support, and privacy pages if published

Required release framing:

- desk reset
- desk discomfort
- neck, shoulder, upper-back, or lower-back tension/stiffness/discomfort
- healthier desk habits
- optional posture awareness

## Privacy and trust gate

Release only if the following are accurate and verified in code:

- camera permission text matches actual camera use
- users are told whether photos are saved locally
- users are told whether pose data is saved locally
- local-only processing claims are true
- delete behavior for saved journal entries is understandable
- no silent sync or upload exists unless documented first

Check these places:

- `Info.plist` camera usage string
- in-app explanation around optional check-ins
- journal UI and delete actions
- privacy policy or support copy if published externally

## Core product gate

The MVP must prove the main habit loop works:

1. user can start a desk reset quickly
2. user can finish a short reset routine
3. completion is saved in the journal
4. reminders can be configured for workday use
5. optional posture check-in does not block the reset flow

The app is not ready if the main experience still feels like a camera-first scanner.

## Platform gate

ResetMinute MVP is iPhone-first only.

Release only if:

- iPhone is the explicit supported platform
- unsupported platform language is removed from product copy
- screenshots and metadata match an iPhone-first product

## Quality gate

Minimum local verification before submission:

- app builds successfully
- first XCTest target passes
- one focused smoke path is exercised on simulator or device
- one real-device pass of the reminder and reset flow is completed
- journal save and delete behavior is manually verified

Current required checks:

- `xcodebuild build -project DeskWellness.xcodeproj -scheme DeskWellness -sdk iphoneos CODE_SIGNING_ALLOWED=NO`
- `xcodebuild test -project DeskWellness.xcodeproj -scheme DeskWellness -destination 'id=<simulator-id>' -parallel-testing-enabled NO`

## App Store gate

Before the first App Store submission, confirm:

- app name and subtitle use the current product direction
- screenshots show desk resets, not clinical posture diagnosis
- description and keywords stay inside the general-wellness boundary
- privacy answers in App Store Connect match the real app behavior
- regulated medical device status is declared as `No` for the current wellness-only app
- support and privacy URLs are live if they are supplied

Do not submit with:

- clinical promises in screenshots
- unimplemented premium claims
- fake real-time monitoring claims
- mismatched privacy labels

## Support and operations gate

Before release, confirm:

- there is one support contact path
- there is one issue log for release blockers
- the current release build and known limitations are documented
- post-release feedback will be reviewed during the first week

## MVP ship decision

The first ResetMinute MVP should ship only when all six areas are green:

- product boundary
- privacy and trust
- core product loop
- platform scope
- quality checks
- App Store readiness

If any one of those is red, the default action is to hold the release and fix the gap rather than expand scope.
