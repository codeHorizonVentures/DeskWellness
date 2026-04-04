# ResetMinute App Store Baseline

This folder is the repo-owned source of truth for the first ResetMinute App Store submission package.

Current scope:

- single locale: `en-US`
- single device class: `iphone-6.9`
- iPhone-first MVP
- general-wellness positioning only

## Structure

- `metadata/en-US/`
  - App Store text and URL baseline for the first English submission
- `screenshots/iphone-6.9/en-US/raw/`
  - direct exports from a passing screenshot xcresult
- `screenshots/iphone-6.9/en-US/final/`
  - visually approved upload set after review

## Screenshot source

The current screenshot suite is:

- `DeskWellnessUITests/ResetMinuteScreenshotUITests.swift`

Expected capture names:

- `01-onboarding.png`
- `02-home-weekly-progress.png`
- `03-reminder-settings.png`
- `04-quick-reset.png`
- `05-journal.png`

Use the export helper to pull the latest attachments from xcresult into `raw/`:

```bash
scripts/export_app_store_screenshots.sh \
  /Users/pdev/Library/Developer/Xcode/DerivedData/DeskWellness-adqromqefsqxobfkxhikovfrbvdn/Logs/Test/Test-DeskWellness-2026.04.04_00-44-42-+0100.xcresult
```

After visual review, copy the approved images from `raw/` into `final/`.

## Submission rule

Do not treat the package as submission-ready unless all of these are aligned:

- screenshots in `final/`
- metadata in `metadata/en-US/`
- live support/privacy URLs
- app copy stays inside the no-certification general-wellness boundary

## Release commands

Approve the current raw screenshot set:

```bash
python3 scripts/app_store_release_system.py approve-screenshots
```

Sync the live listing metadata:

```bash
python3 scripts/app_store_release_system.py sync-metadata
```

Upload the approved iPhone screenshots:

```bash
python3 scripts/app_store_release_system.py sync-iphone-screenshots
```

Verify the current App Store release state:

```bash
python3 scripts/app_store_release_system.py verify --report-path /tmp/resetminute_release_report.json
```
