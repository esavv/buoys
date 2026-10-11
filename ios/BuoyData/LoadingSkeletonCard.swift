import SwiftUI

struct LoadingSkeletonCard: View {
    let height: CGFloat
    var cornerRadius: CGFloat = 16
    let accessibilityLabel: String

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color("FavoriteCardSurface"))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .modifier(SkeletonShimmer())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
    }
}

struct SkeletonShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var sweepColor: Color {
        colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.05)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        let travel = geometry.size.width + geometry.size.height

                        LinearGradient(
                            colors: [.clear, sweepColor, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(
                            width: geometry.size.width * 0.6,
                            height: travel * 2
                        )
                        .rotationEffect(.degrees(30))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .offset(x: isAnimating ? travel : -travel)
                        .animation(
                            .linear(duration: 0.75).delay(0).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .clipped()
            .onAppear { isAnimating = !reduceMotion }
            .onChange(of: reduceMotion) { isAnimating = !reduceMotion }
    }
}

struct BuoyReadingsSkeletonCard: View {
    let stationID: String
    var cornerRadius: CGFloat = 12
    var spacing: CGFloat = 8

    @ScaledMetric(relativeTo: .headline) private var titleHeight = 42
    @ScaledMetric(relativeTo: .caption) private var readingsHeight = 69

    var body: some View {
        LoadingSkeletonCard(
            height: titleHeight + readingsHeight + spacing + 32,
            cornerRadius: cornerRadius,
            accessibilityLabel: "Loading readings for Station \(stationID)"
        )
    }
}
