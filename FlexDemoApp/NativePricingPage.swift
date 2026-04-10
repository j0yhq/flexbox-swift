import SwiftUI

// MARK: - Pricing Page (Native SwiftUI layout + shared card UI)

struct NativePricingPage: View {
    private let columns = [
        GridItem(
            .adaptive(
                minimum: PricingLayoutMetrics.cardWidth,
                maximum: PricingLayoutMetrics.cardWidth
            ),
            spacing: PricingLayoutMetrics.cardGap,
            alignment: .top
        )
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: PricingLayoutMetrics.cardGap) {
            ForEach(PricingPlan.all) { plan in
                PricingPlanCard(plan: plan)
                    .frame(width: PricingLayoutMetrics.cardWidth)
            }
        }
        .frame(maxWidth: PricingLayoutMetrics.maxRowWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, PricingLayoutMetrics.horizontalPadding)
        .padding(.vertical, PricingLayoutMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
