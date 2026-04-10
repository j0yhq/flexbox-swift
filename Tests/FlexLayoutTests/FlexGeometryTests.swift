import XCTest
import SwiftUI
@testable import FlexLayout

#if os(macOS)
import AppKit

private struct ItemFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

@MainActor
private final class FrameRecorder: ObservableObject {
    @Published var frames: [Int: CGRect] = [:]
}

private struct GeometryProbeView: View {
    let config: FlexContainerConfig
    let itemSizes: [CGSize]
    let itemModifiers: [((AnyView) -> AnyView)?]
    let containerSize: CGSize
    @ObservedObject var recorder: FrameRecorder

    var body: some View {
        FlexBox(
            direction: config.direction,
            wrap: config.wrap,
            justifyContent: config.justifyContent,
            alignItems: config.alignItems,
            alignContent: config.alignContent,
            gap: config.gap,
            rowGap: config.rowGap,
            columnGap: config.columnGap,
            padding: config.padding,
            overflow: config.overflow
        ) {
            ForEach(0..<itemSizes.count, id: \.self) { index in
                itemView(at: index)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height, alignment: .topLeading)
        .coordinateSpace(name: "flex-container")
        .onPreferenceChange(ItemFramesPreferenceKey.self) { frames in
            recorder.frames = frames
        }
    }

    private func itemView(at index: Int) -> some View {
        let base = AnyView(
            Color.clear
                .frame(width: itemSizes[index].width, height: itemSizes[index].height)
        )
        let modified = itemModifiers[index]?(base) ?? base

        return modified.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFramesPreferenceKey.self,
                    value: [index: proxy.frame(in: .named("flex-container"))]
                )
            }
        )
    }
}

@MainActor
private func captureFrames(
    config: FlexContainerConfig,
    itemSizes: [CGSize],
    itemModifiers: [((AnyView) -> AnyView)?] = [],
    containerSize: CGSize
) -> [CGRect] {
    let recorder = FrameRecorder()
    let modifiers = itemModifiers.isEmpty
        ? Array(repeating: Optional<((AnyView) -> AnyView)>.none, count: itemSizes.count)
        : itemModifiers

    precondition(modifiers.count == itemSizes.count, "itemModifiers count must match itemSizes count")

    let root = GeometryProbeView(
        config: config,
        itemSizes: itemSizes,
        itemModifiers: modifiers,
        containerSize: containerSize,
        recorder: recorder
    )

    let host = NSHostingView(rootView: root)
    host.frame = CGRect(origin: .zero, size: containerSize)
    host.layoutSubtreeIfNeeded()

    // Preference updates are delivered on the next main-runloop turn.
    for _ in 0..<30 where recorder.frames.count < itemSizes.count {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        host.layoutSubtreeIfNeeded()
    }

    return itemSizes.indices.map { recorder.frames[$0] ?? .null }
}

@MainActor
final class FlexGeometryTests: XCTestCase {
    private let epsilon: CGFloat = 0.5

    private func assertEqual(_ lhs: CGFloat, _ rhs: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(abs(lhs - rhs), epsilon, file: file, line: line)
    }

    func testJustifyContentSpaceBetweenDistributesFreeSpace() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .spaceBetween,
            alignItems: .flexStart
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 40, height: 20), CGSize(width: 40, height: 20), CGSize(width: 40, height: 20)],
            containerSize: CGSize(width: 200, height: 60)
        )

        XCTAssertEqual(frames.count, 3)
        assertEqual(frames[0].minX, 0)
        assertEqual(frames[1].minX, 80)
        assertEqual(frames[2].minX, 160)
    }

    func testAlignItemsCenterCentersItemsOnCrossAxis() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .flexStart,
            alignItems: .center
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 60, height: 20)],
            containerSize: CGSize(width: 200, height: 80)
        )

        XCTAssertEqual(frames.count, 1)
        assertEqual(frames[0].minY, 30)
    }

    func testAlignSelfOverridesContainerAlignItems() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .flexStart,
            alignItems: .flexStart
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 40, height: 20), CGSize(width: 40, height: 20)],
            itemModifiers: [
                { AnyView($0.flexItem(alignSelf: .flexEnd)) },
                nil
            ],
            containerSize: CGSize(width: 200, height: 80)
        )

        XCTAssertEqual(frames.count, 2)
        assertEqual(frames[0].minY, 60)
        assertEqual(frames[1].minY, 0)
    }

    func testWrapReversePlacesNextLineOnOppositeCrossSide() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .wrapReverse,
            justifyContent: .flexStart,
            alignItems: .flexStart,
            gap: 0
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 60, height: 20), CGSize(width: 60, height: 20), CGSize(width: 60, height: 20)],
            containerSize: CGSize(width: 120, height: 120)
        )

        XCTAssertEqual(frames.count, 3)
        // Third item wraps to the second line, and wrap-reverse makes it appear above line 1.
        XCTAssertLessThan(frames[2].minY, frames[0].minY)
    }

    func testRowGapAndColumnGapApplyToCorrectAxes() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .wrap,
            justifyContent: .flexStart,
            alignItems: .flexStart,
            alignContent: .flexStart,
            gap: 0,
            rowGap: 12,
            columnGap: 8
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 50, height: 20), CGSize(width: 50, height: 20), CGSize(width: 50, height: 20)],
            containerSize: CGSize(width: 120, height: 120)
        )

        XCTAssertEqual(frames.count, 3)
        assertEqual(frames[1].minX - frames[0].minX, 58) // width(50) + column-gap(8)
        assertEqual(frames[2].minY - frames[0].minY, 32) // height(20) + row-gap(12)
    }

    func testPaddingOffsetsChildrenInsideContainer() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .flexStart,
            alignItems: .flexStart,
            padding: EdgeInsets(top: 10, leading: 16, bottom: 0, trailing: 0)
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 40, height: 20)],
            containerSize: CGSize(width: 200, height: 100)
        )

        XCTAssertEqual(frames.count, 1)
        assertEqual(frames[0].minX, 16)
        assertEqual(frames[0].minY, 10)
    }

    func testOrderChangesLayoutSequence() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .flexStart,
            alignItems: .flexStart
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 40, height: 20), CGSize(width: 40, height: 20), CGSize(width: 40, height: 20)],
            itemModifiers: [
                { AnyView($0.flexItem(order: 2)) },
                { AnyView($0.flexItem(order: 0)) },
                { AnyView($0.flexItem(order: 1)) }
            ],
            containerSize: CGSize(width: 200, height: 60)
        )

        XCTAssertEqual(frames.count, 3)
        assertEqual(frames[1].minX, 0)
        assertEqual(frames[2].minX, 40)
        assertEqual(frames[0].minX, 80)
    }

    func testAbsolutePositioningRemovesItemFromFlowAndUsesInsets() {
        let config = FlexContainerConfig(
            direction: .row,
            wrap: .nowrap,
            justifyContent: .flexStart,
            alignItems: .flexStart
        )

        let frames = captureFrames(
            config: config,
            itemSizes: [CGSize(width: 40, height: 20), CGSize(width: 30, height: 10)],
            itemModifiers: [
                nil,
                { AnyView($0.flexItem(position: .absolute, top: 5, leading: 7)) }
            ],
            containerSize: CGSize(width: 200, height: 80)
        )

        XCTAssertEqual(frames.count, 2)
        assertEqual(frames[0].minX, 0) // flow item stays at start
        assertEqual(frames[1].minX, 7) // absolute insets
        assertEqual(frames[1].minY, 5)
    }
}
#endif
