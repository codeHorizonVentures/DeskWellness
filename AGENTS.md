# DeskWellness Agent Rules

## Research-First Product Rule

When the user asks for MVP work, product planning, market direction, or strategic changes:
- start with local repo analysis first
- use official external sources when claims touch health, privacy, safety, or regulation
- treat repo documents as source of truth only after they have been updated to reflect the current product direction

## Release Preparation Default

When the user asks to prepare DeskWellness for release, or uses close wording such as:
- `prepare app for release`
- `release preparation`
- `prepare App Store release`
- `update App Store for release`

use a documented release workflow by default.

### Required behavior

1. Propose a short execution plan first.
2. Use the repo release workflow if it exists.
3. If DeskWellness does not yet have a deterministic release system, create or update the release workflow docs before claiming release readiness.
4. Treat build verification, privacy review, App Store metadata accuracy, and test coverage as the minimum release gate.

### Do not do this by default

- do not claim the app is ready without a real build and verification pass
- do not improvise vague release confidence when there is no documented workflow yet
- do not ignore privacy and wellness-claim review for camera-facing features

## IMPORTANT: Standing Development Team Default

When a new Codex session starts for DeskWellness development work, launch the standing role-based development team in parallel by default unless the user explicitly asks for single-agent mode or a reduced team.

### Required behavior

1. Treat the main Codex agent as the integration lead and technical program owner.
2. Start the standing role-agent team at the beginning of substantive project work in a fresh session.
3. Use the operating model in `Documentation/DEVELOPMENT_TEAM_OPERATING_MODEL.md` and the role files in `.codex/agents/` as the source of truth for departments, roles, startup waves, and ownership.
4. Assign tickets and research tasks through the standing team instead of working as a single generalist by default.
5. Route ticket ownership to the correct departments:
   - scan and posture logic through Product, iOS, Privacy/Safety, and QA
   - persistence and journaling changes through Architecture, Data/Reliability, and QA
   - coaching and exercise flows through Product, Design, UX Research, and UX Writing
   - monetization changes through Monetization, App Store, QA, and Product once subscriptions are real
   - release work through Release, App Store, QA, and Security/Privacy
6. Keep validation attached to execution:
   - logic changes must be covered by tests
   - privacy-sensitive changes must include disclosure review
   - release-facing changes must include build and App Store checks
7. Only skip the standing team when the user explicitly narrows the scope or asks not to run sub-agents.

### Standing team startup rule

- On restart, instantiate the standing role agents in parallel.
- Use the role roster from `Documentation/DEVELOPMENT_TEAM_OPERATING_MODEL.md`.
- If Codex has a concurrent agent limit, start the highest-leverage roles first and rotate the remaining specialists in waves until the full roster has been activated for the session.
- If the user gives tickets immediately, distribute them across the active role agents instead of first asking whether to use team mode.

## IMPORTANT: Non-Certification Product Boundary

DeskWellness should stay in the general-wellness lane by default and avoid medical-device certification paths in every market unless the user explicitly asks to pursue a regulated route.

### Required behavior

- do not frame functionality as diagnosis, treatment, prevention, pain relief, rehabilitation, or clinically validated medical outcomes
- do not rely on disclaimers alone; onboarding, in-app copy, metadata, paywalls, and marketing must all stay within the same wellness boundary
- prefer language such as awareness, posture check-in, desk habit, reset, stretch, movement, guidance, and routine
- treat camera processing, local storage, and retention claims as privacy-sensitive and verify them against real behavior before shipping
- if a task would move DeskWellness toward medical or clinical territory, stop and propose a certification-free alternative first

Primary references:
- `Documentation/DEVELOPMENT_TEAM_OPERATING_MODEL.md`
- `Documentation/NO_CERTIFICATION_PRODUCT_BOUNDARY_2026-04-02.md`
- `Documentation/MVP_PROPOSAL_2026-04-02.md`
- `Documentation/PRODUCT_RETHINK_2026-04-02.md`
- `.codex/agents/README.md`
