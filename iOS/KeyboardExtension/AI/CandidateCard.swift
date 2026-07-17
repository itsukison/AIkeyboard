import SwiftUI

enum CandidateCardMetrics {
    static let size = CGSize(width: 330, height: 156)
    static let cornerRadius: CGFloat = 18
}

struct CandidateCard: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        // A tall rewrite would otherwise be truncated. The text scrolls
        // vertically inside the fixed-size card; the axis is orthogonal to the
        // horizontal carousel, so drags partition cleanly (vertical → read,
        // horizontal → switch card). `.basedOnSize` keeps short cards static —
        // no bounce — so only overflowing candidates become scrollable, and the
        // carousel's tap-to-replace (a tap never fires mid-drag) is unaffected.
        ScrollView(.vertical, showsIndicators: true) {
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(KeyboardPalette.ink)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: CandidateCardMetrics.size.width, height: CandidateCardMetrics.size.height)
        .background(
            KeyboardPalette.cardBackground,
            in: RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
                .strokeBorder(isSelected ? KeyboardPalette.accent.opacity(0.7) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous))
    }
}

struct CandidateSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerSkeleton(shape: Capsule()).frame(height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(width: 200, height: 12)
            ShimmerSkeleton(shape: Capsule()).frame(width: 120, height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: CandidateCardMetrics.size.width, height: CandidateCardMetrics.size.height, alignment: .topLeading)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
        )
    }
}

private struct ShimmerSkeleton<S: Shape>: View {
    let shape: S
    @State private var phase: CGFloat = -1

    var body: some View {
        shape
            .fill(Color(uiColor: .systemGray5))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.0), location: 0.0),
                            .init(color: .white.opacity(0.65), location: 0.5),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: phase * width)
                    .blendMode(.plusLighter)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}
