import SwiftUI
import UIKit

struct FeedbackScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSession
    @FocusState private var messageFocused: Bool

    private enum Category: String, CaseIterable {
        case request, bug, other

        var label: LocalizedStringKey {
            switch self {
            case .request: return "機能リクエスト"
            case .bug: return "バグ報告"
            case .other: return "その他"
            }
        }

        var icon: String {
            switch self {
            case .request: return "lightbulb"
            case .bug: return "ladybug"
            case .other: return "ellipsis.bubble"
            }
        }
    }

    private enum Phase: Equatable {
        case editing
        case sending
        case sent
        case failed(String)
    }

    @State private var category: Category = .request
    @State private var message: String = ""
    @State private var phase: Phase = .editing

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedMessage.isEmpty
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Group {
            if phase == .sent {
                FeedbackSentView()
            } else {
                formView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BikeyNavigationBackButton { dismiss() }
            }
        }
        .bikeyKeyboardToolbar { messageFocused = false }
    }

    private var formView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ご意見・ご要望、不具合のご報告をお送りください。")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, BikeyMetrics.Spacing.s)

                sectionLabel("種類")
                    .padding(.top, BikeyMetrics.Spacing.l)

                VStack(spacing: 10) {
                    ForEach(Category.allCases, id: \.self) { option in
                        CategoryCard(
                            icon: option.icon,
                            title: option.label,
                            isSelected: category == option,
                            onTap: {
                                category = option
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        )
                    }
                }
                .padding(.top, BikeyMetrics.Spacing.s + 2)

                sectionLabel("内容")
                    .padding(.top, BikeyMetrics.Spacing.l)

                messageEditor
                    .padding(.top, BikeyMetrics.Spacing.s + 2)

                if case let .failed(text) = phase {
                    Text(text)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(OnboardingPalette.danger)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, BikeyMetrics.Spacing.m)
                        .transition(.opacity)
                }

                OnboardingPrimaryButton(
                    title: "送信",
                    isEnabled: canSubmit,
                    isLoading: phase == .sending,
                    action: submit
                )
                .padding(.top, BikeyMetrics.Spacing.l)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            // Clear the floating LiquidTabBar that overlays the bottom of every tab.
            .padding(.bottom, 110)
        }
        .animation(.easeOut(duration: 0.18), value: phase)
    }

    private func sectionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .bikeyFont(13, weight: .semibold, relativeTo: .footnote)
            .foregroundStyle(AppColor.softText)
            .tracking(0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $message)
                .focused($messageFocused)
                .scrollContentBackground(.hidden)
                .bikeyFont(16, weight: .regular)
                .foregroundStyle(AppColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 168, alignment: .top)

            if message.isEmpty {
                Text("内容を入力してください")
                    .bikeyFont(16, weight: .regular)
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.7))
                    .padding(.horizontal, 19)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnboardingPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(messageFocused ? AppColor.purple : Color.clear, lineWidth: messageFocused ? 1.5 : 0)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .animation(.easeOut(duration: 0.18), value: messageFocused)
    }

    private func submit() {
        guard canSubmit, phase != .sending else { return }
        guard session.profile != nil else {
            phase = .failed("送信するにはサインインが必要です。")
            return
        }
        messageFocused = false
        phase = .sending
        let payload = trimmedMessage
        Task {
            do {
                try await session.submitFeedback(
                    category: category.rawValue,
                    message: payload,
                    appVersion: Self.appVersion
                )
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    phase = .sent
                }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                dismiss()
            } catch {
                phase = .failed("送信できませんでした。通信環境を確認して、もう一度お試しください。")
            }
        }
    }
}

private struct CategoryCard: View {
    let icon: String
    let title: LocalizedStringKey
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColor.purple.opacity(0.12) : AppColor.lavenderMist.opacity(0.7))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(isSelected ? AppColor.purple : AppColor.ink.opacity(0.7))
                }
                .frame(width: 32, height: 32)

                Text(title)
                    .bikeyFont(16, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OnboardingPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: isSelected ? 1.5 : 0)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(CategoryCardPressStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CategoryCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct FeedbackSentView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: BikeyMetrics.Spacing.l) {
            ZStack {
                Circle()
                    .stroke(AppColor.purple.opacity(0.16), lineWidth: 1.5)
                    .frame(width: 96, height: 96)
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1 : 0)

                Circle()
                    .fill(AppColor.charcoalAction)
                    .frame(width: 68, height: 68)
                    .shadow(color: AppColor.charcoalAction.opacity(0.24), radius: 14, x: 0, y: 8)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(appeared ? 0 : -18))
                    .offset(x: appeared ? 0 : -6, y: appeared ? 0 : 6)
            }
            .scaleEffect(appeared ? 1.0 : 0.7)

            VStack(spacing: 8) {
                Text("送信しました")
                    .bikeyFont(22, weight: .semibold, relativeTo: .title2)
                    .foregroundStyle(AppColor.ink)

                Text("ご意見ありがとうございます。\n今後の改善に役立てます。")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
