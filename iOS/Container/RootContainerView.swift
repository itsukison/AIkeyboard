import SwiftUI
import UIKit

@MainActor
final class AppOverlay: ObservableObject {
    enum Modal: Equatable {
        case signOut
        case deleteAccount
        case aiConsent
        case hapticsFullAccessRequired
    }

    @Published var modal: Modal?
    @Published var isDeletingAccount = false
    @Published var deleteAccountError: String?

    func present(_ modal: Modal) {
        deleteAccountError = nil
        self.modal = modal
    }

    func dismiss() {
        modal = nil
        isDeletingAccount = false
        deleteAccountError = nil
    }
}

enum AppTab: String, CaseIterable, Hashable {
    case home
    case prompts
    case profile

    var title: String {
        switch self {
        case .home: return "ホーム"
        case .prompts: return "プロンプト"
        case .profile: return "設定"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house"
        case .prompts: return "text.bubble"
        case .profile: return "person"
        }
    }
}

struct RootContainerView: View {
    @State private var selectedTab: AppTab = .home
    @State private var profileShowsAbout = false
    @StateObject private var stats = ConversionStats.shared
    @StateObject private var overlay = AppOverlay()
    @EnvironmentObject private var session: UserSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("aikJP.hasCompletedFirstRun") private var hasCompletedFirstRun = false
    @AppStorage("aikJP.seenReplyFeature") private var seenReplyFeature = false
    @State private var showReplyFeatureSheet = false

    init(initialTab: AppTab = .home) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                loadingBody
            case .signedOut:
                if hasCompletedFirstRun {
                    signedInBody
                } else {
                    FirstRunFlow(onComplete: { hasCompletedFirstRun = true })
                }
            case .signedIn:
                signedInBody
                    .onAppear { hasCompletedFirstRun = true }
            }
        }
        .environmentObject(overlay)
        .preferredColorScheme(.light)
        .onAppear { stats.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                stats.refresh()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "keigobutton" || url.scheme == "aikeyboard" else { return }
            switch url.host {
            case "fullaccess":
                profileShowsAbout = true
            case "consent":
                overlay.present(.aiConsent)
            default:
                break
            }
            selectedTab = .profile
        }
    }

    @ViewBuilder
    private var loadingBody: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ProgressView()
                .tint(AppColor.ink)
        }
    }

    @ViewBuilder
    private var signedInBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                AppColor.background
                    .ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .home:
                        HomeScreen()
                    case .prompts:
                        PromptsScreen()
                    case .profile:
                        ProfileScreen(showAbout: $profileShowsAbout)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                LiquidTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset + 4)
                    .padding(.bottom, 4)

                if let modal = overlay.modal {
                    overlayModal(for: modal)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeOut(duration: 0.18), value: overlay.modal)
        }
        .sheet(isPresented: $showReplyFeatureSheet) {
            ReplyFeatureSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(AppColor.background)
        }
        .task {
            guard !seenReplyFeature else { return }
            seenReplyFeature = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            showReplyFeatureSheet = true
        }
    }

    @ViewBuilder
    private func overlayModal(for modal: AppOverlay.Modal) -> some View {
        switch modal {
        case .signOut:
            SignOutConfirmModal(
                onCancel: { overlay.dismiss() },
                onConfirm: {
                    overlay.dismiss()
                    Task { await session.signOut() }
                }
            )
        case .deleteAccount:
            DeleteAccountConfirmModal(
                isDeleting: overlay.isDeletingAccount,
                errorMessage: overlay.deleteAccountError,
                onCancel: { overlay.dismiss() },
                onConfirm: {
                    overlay.deleteAccountError = nil
                    overlay.isDeletingAccount = true
                    Task {
                        do {
                            try await session.deleteAccount()
                            overlay.dismiss()
                        } catch {
                            overlay.isDeletingAccount = false
                            overlay.deleteAccountError = error.localizedDescription
                        }
                    }
                }
            )
        case .aiConsent:
            AIConsentInfoModal(onClose: { overlay.dismiss() })
        case .hapticsFullAccessRequired:
            HapticsFullAccessRequiredModal(
                onCancel: { overlay.dismiss() },
                onOpenSettings: {
                    overlay.dismiss()
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            )
        }
    }
}

private struct LiquidTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        tabRow
    }

    private var tabRow: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    guard !isSelected else { return }
                    selectedTab = tab
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack {
                        if isSelected {
                            TabSelectionHighlight()
                                .transition(.opacity)
                        }

                        VStack(spacing: 4) {
                            TabIcon(tab: tab, isSelected: isSelected)
                            Text(tab.title)
                                .bikeyFont(11, weight: .regular, relativeTo: .caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }
                        .foregroundStyle(isSelected ? AppColor.ink : Color.black.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: 70)
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: selectedTab)
        .bikeyInteractiveGlass(in: Capsule(), fallback: .white.opacity(0.92))
        .shadow(color: Color(red: 0.42, green: 0.42, blue: 0.44).opacity(0.20), radius: 18, x: 0, y: 8)
        .shadowIfLegacyChrome(color: .white.opacity(0.75), radius: 2, y: -1)
    }
}

private extension View {
    @ViewBuilder
    func shadowIfLegacyChrome(color: Color, radius: CGFloat, y: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.shadow(color: color, radius: radius, x: 0, y: y)
        }
    }
}

private struct TabSelectionHighlight: View {
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.72))
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.86), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.36, green: 0.36, blue: 0.38).opacity(0.28), radius: 15, x: 0, y: 8)
            .shadow(color: .white.opacity(0.92), radius: 4, x: 0, y: -1)
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
    }
}

private struct TabIcon: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        Group {
            if tab == .profile {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20, weight: .regular))
            } else {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: .regular))
                    .symbolVariant(isSelected ? .fill : .none)
            }
        }
    }
}
