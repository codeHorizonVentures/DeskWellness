# ResetMinute First Submission Baseline

Date: April 4, 2026

## Purpose

This document records the current first-submission package state for ResetMinute after the first screenshot export and hosted-URL setup.

It is the bridge between MVP product work and the actual App Store Connect submission candidate.

## Now in place

### Live public URLs

- Marketing URL: `https://familyfund.app/resetminute/`
- Support URL: `https://familyfund.app/resetminute/support/`
- Privacy Policy URL: `https://familyfund.app/resetminute/privacy/`
- Terms URL: `https://familyfund.app/resetminute/terms/`

### Repo-owned metadata baseline

Stored in:

- `marketing/app_store/metadata/en-US/`

Included now:

- app name
- subtitle
- promotional text
- description
- keywords
- review notes
- marketing/support/privacy URLs

### Repo-owned screenshot baseline

Stored in:

- `marketing/app_store/screenshots/iphone-6.9/en-US/raw/`
- `marketing/app_store/screenshots/iphone-6.9/en-US/final/`

Current raw screenshot set exported from the passing xcresult:

- `01-onboarding.png`
- `02-home-weekly-progress.png`
- `03-reminder-settings.png`
- `04-quick-reset.png`
- `05-journal.png`

Export source:

- `/Users/pdev/Library/Developer/Xcode/DerivedData/DeskWellness-adqromqefsqxobfkxhikovfrbvdn/Logs/Test/Test-DeskWellness-2026.04.04_00-44-42-+0100.xcresult`

Export helper:

- `scripts/export_app_store_screenshots.sh`

## Verified now

- screenshot export works from xcresult into the repo
- exported screenshots are `1320x2868`
- URLs are live and publicly reachable
- app copy, support copy, and privacy copy are aligned to the no-certification desk-wellness boundary

## Still blocking actual submission

1. Final screenshot approval has not happened yet.
   - `raw/` exists
   - `final/` is not approved/populated yet

2. App Store Connect baseline has not been created or verified here.
   - app record/category/privacy answers/review notes still need live ASC entry work

3. Real-device release gate still needs to be completed and recorded.
   - reminder allow/deny/re-enable path
   - quick reset completion path
   - optional check-in path
   - journal delete behavior

4. There is still no ResetMinute-specific upload/release automation.
   - current state is a lightweight repo baseline, not a full release system

## Recommended next actions

1. Review the five raw screenshots and choose the approved upload set.
2. Copy approved images into `marketing/app_store/screenshots/iphone-6.9/en-US/final/`.
3. Create the first App Store Connect app/version entry using the files in `marketing/app_store/metadata/en-US/`.
4. Run and record the real-device release checklist from `Documentation/RELEASE_READINESS_CHECKLIST_2026-04-03.md`.
5. Only after those are green, build a small deterministic submission workflow for ResetMinute.
