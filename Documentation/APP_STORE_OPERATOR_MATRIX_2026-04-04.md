# ResetMinute App Store Operator Matrix

Date: April 4, 2026

## Purpose

This is the operator-facing source of truth for the first ResetMinute App Store submission.

Use it together with:

- `marketing/app_store/metadata/en-US/`
- `marketing/app_store/screenshots/iphone-6.9/en-US/final/`
- `Documentation/RELEASE_READINESS_CHECKLIST_2026-04-03.md`

## Existing app record

Do not create a new app.

- App Store Connect app ID: `6745263811`
- bundle ID: `chv.desk.wellness`
- current internal SKU: `DeskWellness`
- current primary locale: `en-US`

SKU note:

- keep `DeskWellness`
- treat SKU as immutable for this release path

## Listing identity

Set the customer-facing listing to:

- app name: `ResetMinute`
- subtitle: `Desk Breaks for Neck & Back`
- primary category: `Health & Fitness`
- secondary category: `Productivity`

Version rule:

- the selected App Store version must match the project marketing version
- current project marketing version is `1.0`
- current editable App Store version is also `1.0`

## URL fields

Use exactly:

- marketing URL: `https://familyfund.app/resetminute/`
- support URL: `https://familyfund.app/resetminute/support/`
- privacy policy URL: `https://familyfund.app/resetminute/privacy/`

Optional:

- terms URL: `https://familyfund.app/resetminute/terms/`

## Copy fields for the first version

Fill from the repo baseline:

- `marketing/app_store/metadata/en-US/name.txt`
- `marketing/app_store/metadata/en-US/subtitle.txt`
- `marketing/app_store/metadata/en-US/description.txt`
- `marketing/app_store/metadata/en-US/keywords.txt`
- `marketing/app_store/metadata/en-US/review_notes.txt`
- `marketing/app_store/metadata/en-US/marketing_url.txt`
- `marketing/app_store/metadata/en-US/support_url.txt`
- `marketing/app_store/metadata/en-US/privacy_url.txt`

Hold back for the first submission:

- `promotional_text.txt`

Reason:

- keep the first submission package limited to fields that are required and editable for the initial version

## Screenshot package

Approved first upload set:

- `01-onboarding.png`
- `02-home-weekly-progress.png`
- `03-reminder-settings.png`
- `04-quick-reset.png`
- `05-journal.png`

Upload source:

- `marketing/app_store/screenshots/iphone-6.9/en-US/final/`

Slot:

- `APP_IPHONE_67`

## App Privacy answers

Use:

- `No, we do not collect data from this app`

Rationale:

- the current MVP keeps journal entries, check-in photos, pose-related artifacts, and reminder settings on device
- there is no ResetMinute-operated backend for this MVP
- there is no third-party analytics SDK or advertising SDK in the current app

If the product later starts sending any user data off device, these answers must be updated before submission.

## Age rating answers

Current product recommendation:

- all objectionable-content descriptors: `None`
- medical or treatment information: `None`
- unrestricted web access: `No`
- user-generated content: `No`
- advertising: `No`

Expected outcome:

- the minimum age rating available for the current questionnaire path

## Export compliance

Current recommendation:

- `ITSAppUsesNonExemptEncryption = NO` is already set in the project
- if App Store Connect still asks, answer consistently with the current app behavior: the MVP does not implement custom non-exempt encryption beyond standard Apple platform behavior
- no extra export-compliance documentation should be prepared unless the app behavior changes

## Pricing and availability

For the first MVP release:

- price: `Free`
- territories: `All available territories`

Do not scope the first release to a certification-dependent market because the product boundary is general wellness only.

## App Review information

Use these defaults:

- sign-in required: `No`
- demo account required: `No`
- review notes: use `marketing/app_store/metadata/en-US/review_notes.txt`
- review contact email: `support@familyfund.app`
- review contact name: `Petro Kulakov`

Still required manually:

- review contact phone number

Use the same reachable phone number that will actually be monitored during review.

## Release choice

Recommended for the first submission:

- `Manually release this version`

Reason:

- the first live release should be checked one more time after approval before it goes public

## Copyright

Recommended first value:

- `2026 Petro Kulakov`

If the Apple account is operating under a different legal entity for publication, use that exact entity instead.

## Submission gate

Do not submit until all of these are true:

- selected App Store version matches the project marketing version
- the final screenshot set is uploaded
- App Privacy answers are saved
- age rating answers are saved
- review contact phone is entered
- one signed build is uploaded and attached
- the real-device release checklist is complete
