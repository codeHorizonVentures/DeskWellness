# ResetMinute App Store Connect Setup Checklist

Date: April 4, 2026

## Purpose

This checklist defines the minimum App Store Connect setup required to turn the current ResetMinute baseline into a real first submission candidate.

It assumes the repo state already contains:

- live public URLs on `familyfund.app/resetminute/...`
- repo-owned English metadata in `marketing/app_store/metadata/en-US/`
- repo-owned screenshot exports in `marketing/app_store/screenshots/iphone-6.9/en-US/raw/`

## App identity

Use these values from the current project:

- app name: `ResetMinute`
- bundle ID: `chv.desk.wellness`
- display name: `ResetMinute`
- marketing version: `0.1`
- build number: `1` until a new archive increments it

## App record setup

Create or verify the App Store Connect app record with:

- platform: `iOS`
- primary category: `Health & Fitness`
- secondary category: `Productivity`
- age rating and export-compliance answers completed
- support URL: `https://familyfund.app/resetminute/support/`
- privacy policy URL: `https://familyfund.app/resetminute/privacy/`
- marketing URL: `https://familyfund.app/resetminute/`

Optional:

- terms URL: `https://familyfund.app/resetminute/terms/`

Do not point any field to the FamilyFund root page.

## English metadata handoff

Fill the first English metadata entry from:

- `marketing/app_store/metadata/en-US/name.txt`
- `marketing/app_store/metadata/en-US/subtitle.txt`
- `marketing/app_store/metadata/en-US/promotional_text.txt`
- `marketing/app_store/metadata/en-US/description.txt`
- `marketing/app_store/metadata/en-US/keywords.txt`
- `marketing/app_store/metadata/en-US/review_notes.txt`

## Screenshot handoff

Current raw screenshot source:

- `marketing/app_store/screenshots/iphone-6.9/en-US/raw/`

Expected set:

- `01-onboarding.png`
- `02-home-weekly-progress.png`
- `03-reminder-settings.png`
- `04-quick-reset.png`
- `05-journal.png`

Before upload:

1. visually approve the raw set
2. copy the approved images into `marketing/app_store/screenshots/iphone-6.9/en-US/final/`
3. upload only the approved `final/` set

## Privacy answers alignment

Before saving App Store Connect privacy answers, keep them aligned to the actual current app behavior:

- camera is used only for optional check-ins
- reminder notifications use local iPhone notifications
- check-in photos are saved locally only when the user saves a journal entry
- pose-related artifacts are saved locally only when the user saves a journal entry
- there is no ResetMinute-operated backend for journal data or reminders in the current MVP
- there is no silent sync or upload in the current MVP

## Review notes

Use the review note baseline from:

- `marketing/app_store/metadata/en-US/review_notes.txt`

Important reviewer clarification:

- ResetMinute is a general-wellness app
- optional posture check-ins are secondary
- the app is not intended to diagnose, treat, or prevent any medical condition

## Still required outside App Store Connect

These are still blockers even after the ASC record exists:

1. real-device release pass
   - reminder allow path
   - reminder deny and re-enable path
   - quick reset completion path
   - optional check-in path
   - journal delete behavior

2. signed archive / upload flow
   - build an App Store archive for `chv.desk.wellness`
   - upload the build
   - attach the build to version `0.1`

3. final screenshot approval
   - `raw/` is exported
   - `final/` still needs approved assets

## Recommended operator sequence

1. approve the five raw screenshots
2. create the App Store Connect app record
3. enter the English metadata
4. upload the approved screenshot set
5. run the real-device release checklist
6. archive and upload build `0.1`
7. attach the build and complete submission metadata
