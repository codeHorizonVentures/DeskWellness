import SwiftUI

struct ResetMinuteOnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.11, blue: 0.15),
                    Color(red: 0.02, green: 0.03, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .offset(x: 120, y: -260)

            Circle()
                .fill(Color.green.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: -140, y: 240)

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to ResetMinute")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .accessibilityIdentifier("onboarding_screen")

                    Text("A fast desk reset habit for neck, shoulders, and back.")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white.opacity(0.92))

                    Text("Start with a quick reset. Use posture check-ins only when you want extra awareness.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.78))
                }

                VStack(spacing: 14) {
                    OnboardingFeatureCard(
                        icon: "figure.cooldown",
                        title: "Fast by default",
                        detail: "Your daily path is a short reset, not a camera workflow.",
                        tint: .cyan
                    )
                    OnboardingFeatureCard(
                        icon: "camera.viewfinder",
                        title: "Check-ins stay optional",
                        detail: "Use them occasionally if you want a quick desk-awareness snapshot.",
                        tint: .blue
                    )
                    OnboardingFeatureCard(
                        icon: "lock.shield",
                        title: "Saved data stays local",
                        detail: "Photos and pose data stay on your device unless you choose to save a check-in.",
                        tint: .green
                    )
                }

                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Text("Start with Quick Reset")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityIdentifier("onboarding_continue")

                Text("You can open reminders, journal history, and optional check-ins from the home screen.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }
}

private struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.72))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
