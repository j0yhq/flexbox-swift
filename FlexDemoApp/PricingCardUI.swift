import SwiftUI

// MARK: - Shared Pricing Data + Card UI

enum PricingLayoutMetrics {
    static let cardWidth: CGFloat = 280
    static let cardGap: CGFloat = 20
    static let maxRowWidth: CGFloat = 900
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 48
    static let sectionGap: CGFloat = 32
}

struct PricingPlan: Identifiable {
    let id: String
    let name: String
    let price: String
    let period: String
    let description: String
    let features: [String]
    let ctaLabel: String
    let isFeatured: Bool

    static let all: [PricingPlan] = [
        PricingPlan(
            id: "starter",
            name: "Starter",
            price: "$9",
            period: "/mo",
            description: "Basic features for individuals",
            features: ["5 projects", "10 GB storage", "Email support", "Basic analytics"],
            ctaLabel: "Get Started",
            isFeatured: false
        ),
        PricingPlan(
            id: "pro",
            name: "Pro",
            price: "$29",
            period: "/mo",
            description: "Everything you need to grow",
            features: ["Unlimited projects", "100 GB storage", "Priority support", "Advanced analytics", "Custom domains", "Team collaboration"],
            ctaLabel: "Start Free Trial",
            isFeatured: true
        ),
        PricingPlan(
            id: "enterprise",
            name: "Enterprise",
            price: "$99",
            period: "/mo",
            description: "For large teams & organizations",
            features: ["Unlimited everything", "1 TB storage", "Dedicated support", "Custom integrations", "SSO & SAML", "SLA guarantee"],
            ctaLabel: "Contact Sales",
            isFeatured: false
        ),
    ]
}

struct PricingPlanCard: View {
    let plan: PricingPlan

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if plan.isFeatured {
                    Text("Most Popular")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                }

                Text(plan.name)
                    .font(.title3.weight(.semibold))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(plan.price)
                        .font(.system(size: 40, weight: .bold))
                    Text(plan.period)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(plan.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 16))
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack {
                Text(plan.ctaLabel)
                    .font(.headline)
                    .foregroundStyle(plan.isFeatured ? .white : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        plan.isFeatured ? AnyShapeStyle(.blue) : AnyShapeStyle(.blue.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: plan.isFeatured ? .blue.opacity(0.15) : .black.opacity(0.06),
                        radius: plan.isFeatured ? 16 : 8,
                        y: plan.isFeatured ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(plan.isFeatured ? Color.blue : Color.gray.opacity(0.15),
                              lineWidth: plan.isFeatured ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PricingPageHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.largeTitle.bold())

            Text("Start free, upgrade when you're ready. All plans include a 14-day trial.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
