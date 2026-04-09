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
- the five approved screenshots are now populated in `marketing/app_store/screenshots/iphone-6.9/en-US/final/`
- URLs are live and publicly reachable
- app copy, support copy, and privacy copy are aligned to the no-certification desk-wellness boundary
- App Store Connect already contains an app record for bundle ID `chv.desk.wellness` with app ID `6745263811`
- the live App Store Connect listing is now aligned to `ResetMinute` metadata and the five approved iPhone screenshots

## Still blocking actual submission

1. App Store Connect still needs manual operator completion outside the synced listing fields.
   - existing app record: `6745263811`
   - category/privacy answers/review notes still need live ASC entry work
   - operator defaults now live in `Documentation/APP_STORE_OPERATOR_MATRIX_2026-04-04.md`

2. Real-device release gate still needs to be completed and recorded.
   - reminder allow/deny/re-enable path
   - quick reset completion path
   - optional check-in path
   - journal delete behavior

3. There is still no ResetMinute-specific upload/release automation.
   - current state is a lightweight repo baseline, not a full release system

## Recommended next actions

1. Keep the approved screenshot set in `marketing/app_store/screenshots/iphone-6.9/en-US/final/` as the upload baseline.
2. Keep the existing App Store Connect record aligned with `python3 scripts/app_store_release_system.py sync-metadata`.
3. Keep category, review-contact, and copyright fields aligned with `python3 scripts/app_store_release_system.py sync-app-record --contact-phone '<real monitored phone>'`.
4. Keep the App Store screenshot set aligned with `python3 scripts/app_store_release_system.py sync-iphone-screenshots`.
5. Run and record the real-device release checklist from `Documentation/RELEASE_READINESS_CHECKLIST_2026-04-03.md`.
5. Complete the manual App Store operator fields from `Documentation/APP_STORE_OPERATOR_MATRIX_2026-04-04.md`.
6. Archive and upload the signed build for the selected App Store version if the attached build is not the intended release candidate.
