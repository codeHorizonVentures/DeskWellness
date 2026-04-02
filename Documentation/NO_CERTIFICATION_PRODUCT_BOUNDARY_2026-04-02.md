# DeskWellness No-Certification Product Boundary

Date: April 2, 2026

## Decision

DeskWellness should be developed as a general-wellness product and should avoid medical-device certification paths in every market by default.

This means the product should help users build healthier desk habits, posture awareness, and short movement routines for common desk-related discomfort without positioning itself as a diagnostic, therapeutic, preventive, or clinically validated medical product.

## Why this matters

Current DeskWellness code already moves close to the medical boundary in several places:

- `README.md` promises relief from stress, stiffness, and pain.
- `DeskWellness/PostureConstants.swift` uses language such as `clinically validated` and `97%+ reliability`.
- `DeskWellness/ContentView.swift` exposes a paywall promising a `12-Week Clinic`, `Real-time AI Posture Alerts`, and `Pain Relief Tracking`.
- `DeskWellness.xcodeproj/project.pbxproj` says camera video is never saved, while the app actually stores scan photos and posture data locally.

Those are exactly the kinds of product and marketing signals that can move a wellness app into a riskier regulatory and App Review posture.

## Official research basis

### FDA

FDA’s Digital Health Policy Navigator says software intended for maintaining or encouraging a healthy lifestyle and unrelated to diagnosis, cure, mitigation, prevention, or treatment of a disease or condition is likely not a device or may be treated as a low-risk general wellness product.

Source:
- https://www.fda.gov/medical-devices/digital-health-center-excellence/step-3-software-function-intended-maintaining-or-encouraging-healthy-lifestyle

### EU MDR / MDCG

MDCG 2019-11 Rev.1 says intended purpose is derived from the manufacturer’s label, instructions for use, and promotional or sales materials or statements. In practice, disclaimers alone are not enough if the rest of the product positioning makes medical claims.

Source:
- https://health.ec.europa.eu/document/download/b45335c5-1679-4c71-a91c-fc7a4d37f12b_en?filename=mdcg_2019_11_en.pdf

### Apple App Review

Apple requires accurate metadata and treats health and fitness data as sensitive. Misleading claims, inaccurate device data, or privacy mismatches create review risk even if the product is framed as wellness.

Source:
- https://developer.apple.com/app-store/review/guidelines/

### OSHA ergonomic guidance

OSHA’s workstation guidance supports a habit-oriented product direction: change working position frequently, stand up, move, and stretch periodically.

Source:
- https://www.osha.gov/etools/computer-workstations/positions

## Allowed product lane

DeskWellness may safely position itself around:

- posture awareness
- desk-worker habit building
- movement breaks
- stretch routines
- focus and comfort routines
- stiffness, tension, and discomfort management during desk work
- local, on-device scan estimation
- journaling progress and consistency

Good language examples:

- desk posture check-in
- posture awareness
- short reset routine
- gentle desk break guidance
- build healthier desk habits
- helps you notice your posture and move more often
- helps reduce stiffness and tension during long desk sessions
- helps you reset neck, shoulders, and back during the workday

## Language and claims to avoid

DeskWellness should not, by default, claim or imply:

- diagnosis of forward head posture or any condition
- treatment, therapy, rehabilitation, or prevention
- guaranteed pain relief outcomes
- clinical validation or clinical accuracy
- medically personalized advice
- risk scoring for disease, injury, or disability
- use as a substitute for a clinician or physiotherapist

Examples to remove or rewrite:

- `clinically validated`
- `97%+ reliability`
- `pain relief tracking`
- `12-Week Clinic`
- `fix forward head posture`
- `AI posture alerts` if the feature is not real and well-bounded

## Product rules

1. Keep the core promise behavioral, not medical.
2. Do not show clinical thresholds or medical severity labels to users unless strategy changes deliberately.
3. Avoid exposing CVA terminology in user-facing copy unless it is purely informational and non-clinical.
4. Keep any posture score framed as a simple desk-wellness estimate, not a medical assessment.
5. If the product later needs treatment, prevention, pain-outcome, or clinical-efficacy claims, stop and re-evaluate the strategy before shipping.
6. Wellness-safe discomfort language is acceptable only when it stays short-term, non-diagnostic, and non-guaranteed.

## Privacy rules tied to this boundary

Because DeskWellness uses the camera and stores artifacts locally, privacy claims must be exact.

Required rules:

- if scan images or pose data are stored, say so plainly
- if processing is local-only, verify it in code and product copy
- if retention or deletion exists, document it
- if the app later syncs or uploads anything, update privacy and metadata before release

## Immediate repo implications

Before MVP release work, DeskWellness should:

- rewrite product language into general-wellness terms
- remove or defer clinical-sounding claims
- rewrite pain language into wellness-safe discomfort language
- align the camera privacy string with real local storage behavior
- keep marketing, onboarding, paywall, and App Store copy under one product boundary

## Working rule for the team

If a proposed feature or piece of copy would make DeskWellness sound like a medical device, the default answer is to redesign it into a wellness-safe version rather than pursuing certification.
