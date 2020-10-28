import SwiftUI

/// A card with a title and text that can be either vertically or horizontally stacked
struct FlexibleCard: View {
    let axis: Axis
    let title: LocalizedStringKey
    let value: String

    private var descriptionView: some View {
        Text(value)
            .font(Appearance.textFont)
            .fontWeight(Appearance.textFontWeight)
            .foregroundColor(Appearance.textColor)
            .lineLimit(Appearance.textLineLimit)
    }

    private var titleView: some View {
        Text(title)
            .font(Appearance.titleFont)
            .foregroundColor(Appearance.titleColor)
    }

    var body: some View {
        switch axis {
        case .vertical:
            VStack(alignment: .leading) {
                descriptionView
                titleView
            }

        case .horizontal:
            HStack {
                descriptionView
                Spacer()
                titleView
            }
            .flipsForRightToLeftLayoutDirection(true)
        }
    }
}

// MARK: - Appearance
extension FlexibleCard {

    private enum Appearance {
        static let textFont = Font.footnote
        static let textFontWeight = Font.Weight.semibold
        static let textColor = Color(.label)
        static let textLineLimit = 2

        static let titleFont = Font.caption
        static let titleColor = Color(.secondaryLabel)

    }
}
