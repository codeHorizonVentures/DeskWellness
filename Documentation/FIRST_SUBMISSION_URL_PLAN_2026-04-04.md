# ResetMinute First Submission URL Plan

Date: April 4, 2026

## Purpose

This plan defines the minimum public URL structure for the first ResetMinute App Store submission.

The goal is simple:

- one canonical public brand
- one support path
- one privacy path
- no domain confusion
- no unsupported legal or medical claims

## Decision rules

1. Public branding should use `ResetMinute`, not `DeskWellness`.
2. Use one canonical public domain for the MVP.
3. Do not split users across multiple domains or subdomains for the first release.
4. Do not submit placeholder or not-yet-live URLs.
5. If a page is not ready, do not invent copy or domain ownership assumptions.

## Canonical structure

The first release will use `familyfund.app` as the MVP host domain, with ResetMinute living under dedicated product subpaths:

- root landing page: `https://familyfund.app/resetminute/`
- support page: `https://familyfund.app/resetminute/support/`
- privacy policy: `https://familyfund.app/resetminute/privacy/`

Optional:

- terms page: `https://familyfund.app/resetminute/terms/`

## App Store Connect mapping

For the first submission:

- `Support URL` -> `https://familyfund.app/resetminute/support/`
- `Privacy Policy URL` -> `https://familyfund.app/resetminute/privacy/`
- `Marketing URL` -> `https://familyfund.app/resetminute/`

If the landing page is not ready, keep marketing URL blank rather than pointing users to an unfinished page.

The current decision is that the landing page is ready enough to serve as the MVP marketing URL because it is live, product-accurate, and separated from FamilyFund by subpath.

## Required support page content

The support page must be enough for a real user and enough for App Review:

- app name shown as `ResetMinute`
- one support contact path
- short explanation of what the app does
- reminder-permission help
- optional camera check-in explanation
- note that saved data stays on device if that remains true
- current platform scope: iPhone-first

Minimum support sections:

1. `Contact`
2. `How reminders work`
3. `How optional check-ins work`
4. `How to remove saved journal entries`
5. `Known MVP limits`

## Required privacy page content

The privacy page must match actual app behavior exactly.

For the current MVP direction, it should explicitly cover:

- camera use is for optional check-ins
- check-in photos are only saved locally when the user chooses to save a journal entry
- pose-related artifacts are stored locally only if they are actually saved
- reminder scheduling uses local notifications
- no server upload or sync occurs unless that behavior changes later
- deletion/retention behavior for locally saved entries
- support contact path

## Language rules for public pages

Keep the same boundary on the website that is required in the app:

- general wellness only
- desk discomfort and movement breaks
- short resets and healthier desk habits

Do not publish:

- medical-device sounding copy
- treatment or rehabilitation language
- clinical validation claims
- guaranteed pain-relief promises
- `AI posture alerts` or other unimplemented features

## Operational recommendation

For the first submission, the safest path is a minimal static site.

That site only needs:

- one simple landing page
- one support page
- one privacy page

This is enough to satisfy:

- App Review expectations
- support-contact expectations
- privacy-policy accuracy

## Ownership

Before submission, assign clear owners:

- product/design: landing-page copy
- legal/privacy owner: privacy wording review
- engineering/release owner: live URL verification
- support owner: contact path and response plan

## Pre-submit URL gate

Do not treat the URL plan as complete until all of these are true:

- the canonical domain is selected
- public pages use `ResetMinute` branding
- support page is live
- privacy page is live
- content matches the actual app behavior
- App Store Connect fields point to the same canonical domain

## Recommended next step

The initial public page set now exists at:

- `https://familyfund.app/resetminute/`
- `https://familyfund.app/resetminute/support/`
- `https://familyfund.app/resetminute/privacy/`
- `https://familyfund.app/resetminute/terms/`

Use this plan as the source of truth for `DW-21` and the first App Store Connect version entry.
