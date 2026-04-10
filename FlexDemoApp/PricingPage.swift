import SwiftUI
import FlexLayout

// MARK: - Pricing Page (Flex container + shared card UI)

struct PricingPage: View {
    var body: some View {
        FlexBox(wrap: .wrap, justifyContent: .center, gap: PricingLayoutMetrics.cardGap) {
            ForEach(PricingPlan.all) { plan in
                PricingPlanCard(plan: plan)
                    .frame(width: PricingLayoutMetrics.cardWidth)
                    .flexItem(basis: .points(PricingLayoutMetrics.cardWidth))
            }
        }
    }
}
