# DeskWellness MVP Proposal

Date: April 2, 2026

## Executive summary

DeskWellness should not ship as a broad, clinical-sounding posture platform in its current form.

The strongest MVP from the current repo is a focused iPhone-first desk-wellness app with one clear promise:

`help desk workers interrupt long sitting sessions, ease neck/shoulder/back discomfort with short resets, and build a repeatable desk habit`

After deeper research, the stronger interpretation is not a camera-first posture scorer. It is a general-wellness workday reset product for desk workers, with optional posture awareness features around the edge.

That keeps the product inside a general-wellness lane, matches the current codebase better than a desktop or medical product story, and creates a smaller path to a usable first release.

## Current state

What exists today:

- front-camera posture scan flow
- optional side scan
- result summary and score
- canned exercise flow
- local journal save with photos and pose data

What does not exist yet:

- a coherent desktop product
- reminders or background scheduling
- a trustworthy privacy layer and privacy docs
- tests or release infrastructure
- real monetization
- App Store release tooling

Practical reading of the repo:

- DeskWellness is currently an iPhone-first prototype, not a cross-platform desktop app.
- The product is overclaiming relative to what it can responsibly prove.
- The fastest path to MVP is to simplify the value loop around a bigger problem than posture: recurring desk discomfort.

## Research summary

### Official constraint summary

- FDA: healthy-lifestyle software unrelated to diagnosis, cure, mitigation, prevention, or treatment can stay outside the medical-device path if it remains low risk.
- EU MDR / MDCG: intended purpose is defined not just by disclaimers but by labels, instructions, promotional materials, and statements.
- Apple: health-related data is sensitive, privacy claims must be accurate, and misleading claims or inaccurate metadata create review risk.
- OSHA: frequent position changes, stretching, walking around periodically, and doing some tasks standing are part of the healthiest desk-work guidance.

### Market signal summary

Recent posture and stretch apps on the App Store are leaning toward calm reminders, short stretch breaks, and simple daily consistency instead of heavy clinical framing.

Relevant examples:

- Postura – Posture Reminders: https://apps.apple.com/ie/app/postura-posture-reminders/id6757496457
- Stretch Reminder: https://apps.apple.com/us/app/stretch-reminder/id6749167646
- Stand Up! The Work Break Timer: https://apps.apple.com/us/app/stand-up-the-work-break-timer/id828244687
- Posture Reminder: Sit Upright: https://apps.apple.com/us/app/posture-reminder-sit-upright/id6751174987

The addressable user problem is also broad:

- WHO reports `1.71 billion` people living with musculoskeletal conditions globally
- WHO reports `619 million` people affected by low back pain in 2020
- WHO reports `222 million` people affected by neck pain in 2020
- recent office-worker evidence shows neck, low back, and shoulder symptoms are common in desk-heavy populations

Inference from the market and health burden: the safest and most effective MVP is a habit product, not a clinic product, and the strongest problem framing is desk discomfort rather than posture correctness.

## Proposed MVP direction

### Product category

General wellness / Health & Fitness

### Target user

Knowledge workers and remote workers who:

- spend long periods at a desk
- notice neck, shoulder, upper-back, or lower-back discomfort during the day
- want a quick, low-friction reset
- do not want a complicated or medical-feeling experience

### Core product promise

In a minute or two, DeskWellness helps you:

- interrupt a long sitting streak
- do a short guided reset for common desk discomfort areas
- log the habit and stay consistent

### Core loop

1. reminder or self-initiated check-in
2. one short desk reset
3. completion saved
4. streak or weekly consistency

Optional posture check-ins can support this loop, but they should not be the main daily interaction.

## MVP scope

### Must-have features

1. Workday reminder and reset entry point
- simple reminder intervals or work-block timing
- fast access to the reset flow
- snooze and pause behavior that respects real work

2. Short reset routine
- keep the existing 3-exercise routine, but present it as a desk reset
- make it skippable, fast, and clearly timed
- keep exercise copy simple and safe
- focus the first routine set on neck, shoulders, upper back, and lower back

3. Progress journal
- store completed reset sessions
- show a simple consistency history
- keep deletion and local-storage behavior understandable

4. Optional posture check-in
- keep one front-camera check-in only if it adds real value
- treat it as occasional awareness, not the main daily loop
- keep result wording simple and non-clinical
- do not make posture correctness the primary promise

5. Privacy and trust layer
- clear explanation of what is stored locally
- accurate camera permission copy
- visible non-medical wellness framing

### Should-have features for MVP if time allows

- reminder settings for daily or workday check-ins
- basic streak or weekly consistency summary
- one lightweight onboarding screen explaining the habit loop

### Explicit non-goals for MVP

Do not include these in the first MVP release:

- clinical validation claims
- chronic pain treatment claims
- treatment or rehabilitation framing
- a `clinic` or program-style paywall
- daily camera-first scan as the only main workflow
- real-time always-on posture monitoring
- server-side data processing
- true multi-platform desktop support
- complex analytics dashboards
- broad category of exercise plans

## Product cuts from the current repo direction

The MVP should cut or rewrite:

- customer-facing CVA and clinical framing
- pain-treatment wording
- `12-Week Clinic` positioning
- `AI posture alerts` promises until they are real, useful, and safe
- fake or placeholder premium entry points
- desktop positioning until the product genuinely supports it
- camera-first framing as the daily default

## Monetization stance

Do not make subscriptions a first-order problem before the habit loop works.

Recommended sequence:

1. prove reminder-to-reset activation and repeat use
2. add reminder customization or premium routine packs later
3. only then add a real paywall and subscription system

If monetization is needed early, keep it narrow:

- premium routines
- deeper history or export
- advanced customization

Do not paywall the core check-in and reset loop in MVP.

## MVP success metrics

Track these first:

- reminder opt-in rate
- reminder-to-reset completion rate
- reset completion rate
- completion by body-area routine
- journal save rate
- reminder opt-in rate
- day-7 repeat use
- weekly active users completing at least 3 reset sessions

Secondary metrics:

- optional posture check-in usage
- posture check-in to reset completion

Do not optimize for subscription conversion before those are healthy.

## Delivery plan

### Phase 0: Foundation and product truth

- choose one platform story: iPhone-first
- fix privacy text to match storage behavior
- remove clinical or pain-relief claims
- clean the build environment and target configuration
- add first test target and minimal smoke coverage

### Phase 1: MVP build

- add the reminder and reset loop
- keep one short reset routine flow
- tune the initial routine set around neck, shoulders, upper back, and lower back discomfort
- simplify scan flow into an optional feature
- simplify results language
- stabilize journal and deletion behavior
- add minimal onboarding and settings

### Phase 2: Post-MVP iteration

- reminders
- better retention instrumentation
- visual polish and App Store assets
- limited premium strategy if activation is strong

## Recommended next engineering priorities

1. Align privacy and product claims with actual behavior.
2. Resolve platform confusion and define DeskWellness as iPhone-first for the first release.
3. Build the reminder and reset habit loop before investing more in posture scoring.
4. Simplify the result model from clinical-sounding posture scoring to optional desk-wellness check-ins.
5. Add test scaffolding and release docs before serious release preparation.

## Recommendation

Ship DeskWellness first as a small, trustworthy, non-clinical desk-wellness app for desk workers.

The main daily value should be reminders and short resets for neck, shoulder, upper-back, and lower-back discomfort. Optional posture check-ins can stay, but they should no longer define the product.

If the product proves that users return for quick resets and consistent desk habits, then expand. If not, do not add clinical complexity or monetization complexity to compensate for an unproven core loop.
