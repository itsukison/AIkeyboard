import SwiftUI

enum CandidateCardMetrics {
    static let size = CGSize(width: 330, height: 156)
    static let cornerRadius: CGFloat = 18
}

struct CandidateCard: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(KeyboardPalette.ink)
            .lineLimit(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: CandidateCardMetrics.size.width, height: CandidateCardMetrics.size.height, alignment: .topLeading)
            .background(
                KeyboardPalette.cardBackground,
                in: RoundedRectangle(cornerRadius: CandidateCardMetrics.cornerRadius, style: .continuous)
            )
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
