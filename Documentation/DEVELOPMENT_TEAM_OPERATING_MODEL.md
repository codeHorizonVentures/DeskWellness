# DeskWellness Development Team Operating Model

This document defines the standing multi-department development team for DeskWellness and the role-agent roster that Codex should launch at the start of a fresh project session.

The concrete agent definitions live in `.codex/agents/`.

## Design goals

- keep product delivery cross-functional
- keep desk-worker habit value, privacy review, and claim safety explicit
- embed design and UX in delivery, not as a downstream service
- keep QA, release, App Store, analytics, safety, and legal review as named owners
- make the main Codex agent the integration lead, not the only specialist
- make behavior-focused testing the default engineering execution model
- keep DeskWellness inside a non-regulated general-wellness product lane by default

## Organization model

DeskWellness should run as:

- one integration lead
- a standing role-agent team
- departments that provide standards, ownership, and review accountability
- ticket execution delegated across the standing role agents

## Engineering execution standard

DeskWellness engineering work should default to behavior-focused testing.

Execution rules:

- test what the code does, not how it is internally structured
- prefer the Testing Trophy order of investment:
  integration tests first, unit tests for pure logic, a few critical end-to-end flows, and static analysis as a constant safety net
- use integration tests as the default for most feature work and user-facing regressions
- use unit tests where they are strongest:
  algorithms, state machines, parsers, business rules, and other complex logic
- avoid low-value tests for glue code, trivial accessors, and layout-only UI details unless they cover a real risk
- write tests alongside code by default; use strict TDD when it helps, but do not force it when it does not improve delivery
- lean on Swift types, static analysis, and previews to remove low-value runtime tests where possible
- prefer testing view models, repositories, and app boundaries over direct SwiftUI view-structure tests
- use a small number of critical end-to-end or UI flows instead of trying to exhaustively automate the full UI surface
- use snapshot or golden tests when stable UI output or serialization shape matters more than implementation details
- treat tests as shared delivery ownership across Architecture, iOS Engineering, Data/Reliability, and QA

## Product boundary

DeskWellness is currently an iPhone-first desk-wellness product with optional posture-awareness features, not a certified medical product and not a true desktop platform app.

Default product rules:

- prioritize a general-wellness reminder and reset loop over camera-led scoring or medical positioning
- treat platform scope as an explicit product decision; until changed deliberately, DeskWellness should be managed as an iPhone-first product with future expansion options
- keep privacy and user-facing claims consistent with actual data behavior
- do not ship medical claims, pain-relief promises, or clinical-validity claims without an intentional strategy change

## Departments

### Product and Delivery Department

Owns product direction, prioritization, ticket framing, acceptance criteria, and coordination across engineering and design.

Roles:

- Product Lead
- Delivery Manager

### Architecture and iOS Engineering Department

Owns app architecture, SwiftUI structure, state boundaries, scan-flow implementation, journaling, posture engine integration, and core iOS implementation quality.

Roles:

- Mobile Architect
- iOS Tech Lead
- Core iOS Developer
- Data and Reliability Engineer
- Monetization Engineer

### Design, UI, and UX Department

Owns product design quality, UI consistency, coaching flows, interaction design, research, content clarity, and accessibility-informed decisions.

Roles:

- Product Designer
- Visual UI Designer
- UX Researcher
- UX Writer

### Quality and Test Engineering Department

Owns release confidence, smoke-test coverage, regression strategy, and automation standards.

Roles:

- QA Automation Lead

### Release, Platform, and App Store Department

Owns build verification, release workflows, metadata readiness, screenshot strategy, and release-readiness checks.

Roles:

- Release Engineer
- App Store and ASO Manager

### Security, Privacy, and Safety Department

Owns camera permission accuracy, local-processing claims, data retention review, privacy disclosures, and non-medical safety framing.

Roles:

- Security and Privacy Engineer

### Legal and Regulatory Department

Owns regulated-status interpretation, App Store permit declarations, content-rights review support, and release-facing legal consistency for a non-medical wellness product.

Roles:

- Legal Counsel

### Analytics and Growth Department

Owns event design, activation measurement, retention visibility, growth analysis, and experiment framing.

Roles:

- Analytics and Growth Analyst

## Standing role-agent roster

### 1. Integration Lead

Purpose:
- keeps the whole program coherent
- breaks work into agent scopes
- integrates outputs and final code changes

Default owner:
- main Codex agent

### 2. Product Lead Agent

Purpose:
- turns broad requests into product outcomes, acceptance criteria, and ticket priorities

Primary ownership:
- scan flow value
- exercise loop
- journaling habit loop
- MVP scope decisions

### 3. Delivery Manager Agent

Purpose:
- keeps execution moving, identifies blockers, sequences work, and tracks dependency order

Primary ownership:
- ticket routing
- sprint-style coordination
- risk and dependency tracking

### 4. Mobile Architect Agent

Purpose:
- protects app structure, platform boundaries, and long-term maintainability

Primary ownership:
- `DeskWellness/DeskWellnessApp.swift`
- `DeskWellness/ContentView.swift`
- module seams
- platform-scope decisions

### 5. iOS Tech Lead Agent

Purpose:
- owns implementation direction for SwiftUI features, scan flow, and engineering quality across user-facing app code

Primary ownership:
- SwiftUI implementation quality
- posture scan UX implementation
- cross-feature code review
- engineering patterns and performance tradeoffs
- behavior-focused test strategy across implementation work

### 6. Core iOS Developer Agent

Purpose:
- implements user-facing app work across scan, results, exercise, journal, and settings flows

Primary ownership:
- `DeskWellness/ContentView.swift`
- `DeskWellness/PostureTipView.swift`
- `DeskWellness/JournalView.swift`
- visual user flow implementation
- high-value regression coverage with QA coordination

### 7. Data and Reliability Engineer Agent

Purpose:
- owns persistence correctness, journal integrity, photo retention behavior, and future migration safety

Primary ownership:
- `DeskWellness/JournalModels.swift`
- `DeskWellness/JournalView.swift`
- photo persistence and cleanup paths
- future SwiftData migration paths
- persistence-focused integration coverage and logic-level tests where they pay off

### 8. Monetization Engineer Agent

Purpose:
- owns subscriptions, paywall logic, offer logic, and premium-state correctness when monetization becomes real

Primary ownership:
- `DeskWellness/ContentView.swift` paywall path
- StoreKit or subscription integration once added
- premium-state behavior

### 9. Product Designer Agent

Purpose:
- owns product flow quality, interaction design, and UX coherence

Primary ownership:
- first-run scan flow
- result comprehension
- exercise completion flow
- journal habit loop

### 10. Visual UI Designer Agent

Purpose:
- owns visual polish, composition, typography, spacing, and screenshot-ready presentation

Primary ownership:
- scan/result screen polish
- App Store-ready key surfaces
- visual-system quality

### 11. UX Researcher Agent

Purpose:
- represents user evidence, friction analysis, usability hypotheses, and research-driven recommendations

Primary ownership:
- habit-loop friction analysis
- scan completion failure analysis
- desk-worker use-case research
- validation-market research inputs

### 12. UX Writer Agent

Purpose:
- owns in-product copy, wellness framing, exercise instructions, and clarity of labels and messaging

Primary ownership:
- coaching copy
- posture-result wording
- onboarding and paywall language
- privacy-sensitive copy review support

### 13. QA Automation Lead Agent

Purpose:
- protects regression quality with focused unit, integration, and UI smoke coverage

Primary ownership:
- future `DeskWellnessTests/`
- future `DeskWellnessUITests/`
- build verification and release test requirements
- regression proof through the highest-value mix of integration, unit, and critical end-to-end tests

### 14. Release Engineer Agent

Purpose:
- owns automation, delivery tooling, release commands, and readiness verification

Primary ownership:
- future `fastlane/`
- future `scripts/`
- release workflow documentation and tooling

### 15. Security and Privacy Engineer Agent

Purpose:
- reviews camera permissions, local data handling, retention behavior, and safety-sensitive claims

Primary ownership:
- camera/privacy disclosures
- local storage behavior
- privacy policy alignment
- wellness-safety product boundary review

### 16. Legal Counsel Agent

Purpose:
- owns regulatory interpretation, App Store compliance declarations, and legal-risk review for public product claims

Primary ownership:
- regulated medical device declaration guidance
- App Store regulatory and permit review
- wellness-boundary legal review for metadata and marketing surfaces
- content-rights review support

### 17. Analytics and Growth Analyst Agent

Purpose:
- owns event schema quality, activation measurement, and retention-oriented experimentation

Primary ownership:
- scan completion metrics
- exercise completion metrics
- journal retention metrics
- post-MVP growth instrumentation

### 18. App Store and ASO Manager Agent

Purpose:
- owns App Store positioning quality, metadata, screenshots, and market-facing release materials

Primary ownership:
- future App Store metadata manifests
- screenshot strategy
- localization and ASO priorities

## Startup waves

### Core startup wave

Use this wave first in fresh sessions because it covers MVP delivery and current DeskWellness risks.

- Product Lead
- Delivery Manager
- Mobile Architect
- iOS Tech Lead
- Core iOS Developer
- Product Designer
- QA Automation Lead
- Security and Privacy Engineer

### Specialist wave

Use this wave once the core wave has context or when the ticket touches these areas directly.

- Data and Reliability Engineer
- UX Researcher
- UX Writer
- Analytics and Growth Analyst
- Legal Counsel

### Market and scale wave

Use this wave when the work is release-facing, monetization-facing, or App Store-facing.

- Visual UI Designer
- Release Engineer
- App Store and ASO Manager
- Monetization Engineer

## Ticket routing defaults

- posture detection and result logic: Product Lead, Mobile Architect, iOS Tech Lead, Security and Privacy Engineer, QA Automation Lead
- coaching and exercise content: Product Lead, Product Designer, UX Researcher, UX Writer, Core iOS Developer
- journaling and persistence: Mobile Architect, Data and Reliability Engineer, Core iOS Developer, QA Automation Lead
- paywall and subscription work: Monetization Engineer, Product Lead, UX Writer, QA Automation Lead, App Store and ASO Manager
- release work: Release Engineer, QA Automation Lead, Security and Privacy Engineer, Legal Counsel, App Store and ASO Manager
- regulatory, policy, and market-claim work: Product Lead, Security and Privacy Engineer, Legal Counsel, UX Writer, App Store and ASO Manager
- growth work: Analytics and Growth Analyst, Product Lead, UX Researcher, App Store and ASO Manager
