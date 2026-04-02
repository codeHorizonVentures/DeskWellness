# DeskWellness Jira Project Proposal

Date: April 3, 2026

## Recommendation

Yes. A separate Jira project for DeskWellness would help.

It would help because DeskWellness is no longer just "another app idea." It now has:

- a distinct product boundary
- a distinct MVP direction
- a distinct release path
- different risks from FamilyFund

Without a separate project, strategy, research, copy, privacy work, and engineering work will blur together and lose priority.

## Why a separate project helps

### 1. Separate product truth

DeskWellness now has a different core promise:

`help desk workers reduce neck, shoulder, and back discomfort during long workdays with short guided resets`

That needs its own backlog and acceptance criteria.

### 2. Better MVP focus

A dedicated project lets us keep the first backlog centered on:

- reminder loop
- reset routines
- privacy corrections
- claim cleanup
- iPhone-first release path

instead of mixing it with posture-scanner or unrelated ideas.

### 3. Better risk control

DeskWellness has specific risks that deserve their own tickets:

- claim safety
- privacy disclosure accuracy
- camera/data retention behavior
- platform confusion
- release readiness gap

### 4. Better decision speed

If we use Jira well, I can use it to:

- convert research into tickets
- separate must-have MVP work from later ideas
- track blockers and dependencies
- keep the team aligned on the no-certification boundary

## Recommended Jira project shape

Project name:

`DeskWellness`

Suggested key:

`DW`

Project type:

`Software project`

Recommended board:

- one product board for MVP delivery

## Suggested epics

1. `DW-EPIC-1` Product Repositioning
- desk discomfort positioning
- wellness-safe copy
- removal of clinical and clinic-style claims

2. `DW-EPIC-2` Core MVP Habit Loop
- reminders
- reset flow
- streak and weekly consistency

3. `DW-EPIC-3` Optional Posture Awareness
- optional camera check-in
- simplified result language
- privacy-accurate storage messaging

4. `DW-EPIC-4` Privacy, Safety, and Trust
- camera disclosure fixes
- retention and deletion behavior
- policy and in-app disclosure alignment

5. `DW-EPIC-5` Quality and Release Foundation
- tests
- release workflow
- App Store metadata
- screenshot and build verification

## Suggested first MVP tickets

1. Rewrite the product promise around desk discomfort instead of posture correctness.
2. Remove clinical, clinic, and pain-treatment language from the app.
3. Fix privacy strings to match actual local photo and pose-data storage.
4. Define the iPhone-first platform scope in code and docs.
5. Add reminder scheduling for workday resets.
6. Reframe the existing exercise flow as short neck/shoulder/back reset routines.
7. Simplify the journal into reset completion history first.
8. Make camera posture check-in optional instead of the default landing flow.
9. Add the first unit-test target and one smoke test path.
10. Create the first release-readiness checklist.

## Suggested issue types

- Epic
- Story
- Task
- Bug
- Research

## Suggested workflow

Statuses:

- Backlog
- Ready
- In Progress
- Review
- Done

## Recommended working rule

Do not add feature ideas to the MVP board unless they clearly improve one of these:

- reminder activation
- reset completion
- repeat use
- privacy trust
- release readiness

## Bottom line

A separate Jira project is useful here because DeskWellness now has enough product definition to benefit from disciplined backlog control.

If you want, the next step is:

1. create Jira project `DeskWellness` with key `DW`
2. create the 5 epics above
3. seed the first 10 MVP tickets
