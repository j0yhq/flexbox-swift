import SwiftUI
import FlexLayout

// MARK: - Pricing Page
// Pure FlexBox layout. No GeometryReader, no HStack/VStack.
// Plans wrap responsively using flex-wrap + width:100% + basis:280.

struct PricingPage: View {
    var body: some View {
        FlexBox(direction: .column, gap: 32,
                padding: EdgeInsets(top: 48, leading: 24, bottom: 48, trailing: 24),
                overflow: .scroll) {

            PageHeader()
                .flexItem(shrink: 0)

            PlansRow()
                .flexItem(shrink: 0, width: .fraction(1.0))
        }
    }
}

// MARK: - Page Header

private struct PageHeader: View {
    var body: some View {
        FlexBox(direction: .column, alignItems: .center, gap: 12) {
            Text("Choose Your Plan")
                .font(.largeTitle.bold())
                .flexItem(shrink: 0)
            Text("Start free, upgrade when you're ready. All plans include a 14-day trial.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .flexItem(shrink: 0)
        }
    }
}

// MARK: - Plans Row (wraps)

private struct PlansRow: View {
    var body: some View {
        FlexBox(direction: .row, wrap: .wrap, justifyContent: .center,
                alignItems: .flexStart, gap: 20) {
            PlanCard(plan: .starter)
                .flexItem(grow: 1, shrink: 0, basis: .points(280))
            PlanCard(plan: .pro)
                .flexItem(grow: 1, shrink: 0, basis: .points(280))
            PlanCard(plan: .enterprise)
                .flexItem(grow: 1, shrink: 0, basis: .points(280))
        }
    }
}

// MARK: - Plan Data

private struct PlanData {
    let name: String
    let price: String
    let period: String
    let description: String
    let features: [String]
    let ctaLabel: String
    let isFeatured: Bool

    static let starter = PlanData(
        name: "Starter", price: "$9", period: "/mo",
        description: "Basic features for individuals",
        features: ["5 projects", "10 GB storage", "Email support", "Basic analytics"],
        ctaLabel: "Get Started", isFeatured: false
    )
    static let pro = PlanData(
        name: "Pro", price: "$29", period: "/mo",
        description: "Everything you need to grow",
        features: ["Unlimited projects", "100 GB storage", "Priority support", "Advanced analytics", "Custom domains", "Team collaboration"],
        ctaLabel: "Start Free Trial", isFeatured: true
    )
    static let enterprise = PlanData(
        name: "Enterprise", price: "$99", period: "/mo",
        description: "For large teams & organizations",
        features: ["Unlimited everything", "1 TB storage", "Dedicated support", "Custom integrations", "SSO & SAML", "SLA guarantee"],
        ctaLabel: "Contact Sales", isFeatured: false
    )
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PlanData

    var body: some View {
        FlexBox(direction: .column, gap: 0) {
            CardHeader(plan: plan)
                .flexItem(shrink: 0)
            FeatureList(features: plan.features)
                .flexItem(grow: 1)
            CTAButton(label: plan.ctaLabel, isFeatured: plan.isFeatured)
                .flexItem(shrink: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: plan.isFeatured ? .blue.opacity(0.15) : .black.opacity(0.06),
                        radius: plan.isFeatured ? 16 : 8, y: plan.isFeatured ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(plan.isFeatured ? Color.blue : Color.gray.opacity(0.15),
                              lineWidth: plan.isFeatured ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Card sub-views

private struct CardHeader: View {
    let plan: PlanData

    var body: some View {
        FlexBox(direction: .column, alignItems: .center, gap: 8,
                padding: EdgeInsets(top: 28, leading: 24, bottom: 20, trailing: 24)) {

            if plan.isFeatured {
                Text("Most Popular")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.blue, in: Capsule())
                    .flexItem(shrink: 0)
            }

            Text(plan.name)
                .font(.title3.weight(.semibold))
                .flexItem(shrink: 0)

            FlexBox(direction: .row, alignItems: .baseline, gap: 2) {
                Text(plan.price)
                    .font(.system(size: 40, weight: .bold))
                    .flexItem(shrink: 0)
                Text(plan.period)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)

            Text(plan.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .flexItem(shrink: 0)
        }
    }
}

private struct FeatureList: View {
    let features: [String]

    var body: some View {
        FlexBox(direction: .column, alignItems: .flexStart, gap: 12,
                padding: EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)) {
            ForEach(features, id: \.self) { feature in
                FeatureRow(text: feature)
                    .flexItem(shrink: 0)
            }
        }
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        FlexBox(direction: .row, alignItems: .center, gap: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
                .flexItem(shrink: 0)
            Text(text)
                .font(.subheadline)
                .flexItem(grow: 1)
        }
    }
}

private struct CTAButton: View {
    let label: String
    let isFeatured: Bool

    var body: some View {
        FlexBox(direction: .row, justifyContent: .center,
                padding: EdgeInsets(top: 16, leading: 24, bottom: 24, trailing: 24)) {
            Text(label)
                .font(.headline)
                .foregroundStyle(isFeatured ? .white : .blue)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    isFeatured ? AnyShapeStyle(.blue) : AnyShapeStyle(.blue.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .flexItem(grow: 1)
        }
    }
}
