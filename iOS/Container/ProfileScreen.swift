import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject private var session: UserSession
    @EnvironmentObject private var overlay: AppOverlay
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var stats = ConversionStats.shared
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
    @State private var showPersonalInfo = false
    @State private var showKeyboardStyle = false
    @State private var keyboardStyle: KeyboardPreferences.KeyboardStyle = KeyboardSettingsStore.readKeyboardStyle()
    @State private var promptCount: Int = UserPromptStore.readEntries().count
    @Binding var showAbout: Bool
    @State private var showAuth = false
    @AppStorage(KeyboardSettingsStore.hapticsEnabledKey, store: KeyboardSettingsStore.sharedDefaults)
    private var hapticsEnabled = false

    init(showAbout: Binding<Bool> = .constant(false)) {
        _showAbout = showAbout
    }

    private var keyboardStyleDisplayName: LocalizedStringKey {
        switch keyboardStyle {
        case .japaneseFlick: return "フリック"
        case .japaneseRomaji: return "ローマ字"
        case .standard: return "ローマ字"
        }
    }

    private var accountRows: [ProfileRowModel] {
        if session.profile == nil {
            return [
                .init(
                    icon: "person.crop.circle.badge.plus",
                    title: "サインイン / アカウントを作成",
                    action: { showAuth = true }
                )
            ]
        }
        return [
            .init(
                icon: "person",
                title: "ユーザー情報",
                action: { showPersonalInfo = true }
            ),
            .init(
                icon: "rectangle.portrait.and.arrow.right",
                title: "サインアウト",
                action: { overlay.present(.signOut) }
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileTopControls()
                        .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileCard(displayName: session.displayName, stats: stats, promptCount: promptCount)
                        .padding(.top, BikeyMetrics.Spacing.l - 4)

                    ProfileSectionTitle("アカウント")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(rows: accountRows)
                    .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileSectionTitle("その他")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "keyboard",
                                title: "キーボード入力方式",
                                trailing: keyboardStyleDisplayName,
                                action: { showKeyboardStyle = true }
                            ),
                            .init(
                                icon: "hand.tap",
                                title: "触覚フィードバック",
                                toggle: hapticsBinding
                            ),
                            .init(
                                icon: "info.circle",
                                title: "敬語ボタンについて",
                                action: { showAbout = true }
                            )
                        ]
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    Spacer(minLength: 84)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
            .navigationDestination(isPresented: $showPersonalInfo) {
                PersonalInformationView(profile: session.profile)
            }
            .navigationDestination(isPresented: $showKeyboardStyle) {
                KeyboardStylePickerView(selection: $keyboardStyle)
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutScreen()
            }
            .onAppear {
                KeyboardSettingsStore.writeCloudAIEnabled(true)
                promptCount = UserPromptStore.readEntries().count
                refreshFullAccessState()
            }
            .onChange(of: session.profile) { _ in
                KeyboardSettingsStore.writeCloudAIEnabled(true)
                promptCount = UserPromptStore.readEntries().count
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    refreshFullAccessState()
                }
            }
            .guestAuthCover(isPresented: $showAuth)
        }
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { hapticsEnabled },
            set: { enabled in
                if enabled {
                    refreshFullAccessState()
                    guard keyboardStatus.isFullAccessEnabled else {
                        hapticsEnabled = false
                        overlay.present(.hapticsFullAccessRequired)
                        return
                    }
                }
                hapticsEnabled = enabled
            }
        )
    }

    private func refreshFullAccessState() {
        keyboardStatus.refresh()
    }
}

private struct PersonalInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var overlay: AppOverlay
    @AppStorage(AppThemePreference.storageKey) private var themePreference: String = AppThemePreference.auto.rawValue
    @AppStorage(AppLanguage.storageKey) private var languagePreference: String = AppLanguage.system.rawValue

    let profile: UserSession.Profile?

    private var theme: AppThemePreference {
        AppThemePreference(rawValue: themePreference) ?? .auto
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languagePreference) ?? .system
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var joinedDate: String? {
        profile.map { Self.dateFormatter.string(from: $0.createdAt) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                identityCard
                    .padding(.top, BikeyMetrics.Spacing.s)

                ProfileSectionTitle("表示")
                    .padding(.top, BikeyMetrics.Spacing.l + 2)

                themeCard
                    .padding(.top, BikeyMetrics.Spacing.s)

                ProfileSectionTitle("言語")
                    .padding(.top, BikeyMetrics.Spacing.l + 2)

                languageCard
                    .padding(.top, BikeyMetrics.Spacing.s)

                deleteButton
                    .padding(.top, BikeyMetrics.Spacing.xl)

                Spacer(minLength: BikeyMetrics.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("ユーザー情報")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BikeyNavigationBackButton { dismiss() }
            }
        }
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: BikeyMetrics.Spacing.m - 4) {
                ProfilePortrait()
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: profile?.displayName.isEmpty == false ? profile!.displayName : "—")
                        .bikeyFont(18, weight: .medium, relativeTo: .title3)
                        .foregroundStyle(AppColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(verbatim: profile?.email ?? "—")
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
            .frame(minHeight: 74)

            if let joinedDate {
                Divider()
                    .overlay(Color.black.opacity(0.035))
                    .padding(.leading, 56 + BikeyMetrics.Spacing.l - 1)
                    .padding(.trailing, BikeyMetrics.Spacing.m)

                HStack {
                    Text("登録日")
                        .bikeyFont(15, weight: .regular, relativeTo: .body)
                        .foregroundStyle(AppColor.ink.opacity(0.86))
                    Spacer()
                    Text(verbatim: joinedDate)
                        .bikeyFont(14, weight: .regular, relativeTo: .body)
                        .foregroundStyle(AppColor.muted.opacity(0.82))
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
                .frame(minHeight: 54)
            }
        }
        .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }

    private var themeCard: some View {
        HStack(spacing: 10) {
            ForEach(AppThemePreference.allCases) { option in
                ThemeOptionCard(
                    option: option,
                    isSelected: option == theme,
                    onTap: {
                        themePreference = option.rawValue
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                )
            }
        }
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, option in
                Button {
                    guard option != language else { return }
                    languagePreference = option.rawValue
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    HStack(spacing: BikeyMetrics.Spacing.m - 3) {
                        option.pickerLabel
                            .bikeyFont(15, weight: .regular, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)

                        Spacer()

                        if option == language {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColor.purple)
                        }
                    }
                    .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == language ? [.isSelected] : [])

                if index < AppLanguage.allCases.count - 1 {
                    Divider()
                        .overlay(Color.black.opacity(0.035))
                        .padding(.leading, BikeyMetrics.Spacing.l - 1)
                        .padding(.trailing, BikeyMetrics.Spacing.m)
                }
            }
        }
        .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            overlay.present(.deleteAccount)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .regular))
                Text("アカウントを削除")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
            }
            .foregroundStyle(Color(red: 0.847, green: 0.306, blue: 0.345))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColor.surface, in: Capsule())
            .overlay(
                Capsule().stroke(Color(red: 0.847, green: 0.306, blue: 0.345).opacity(0.34), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileTopControls: View {
    var body: some View {
        Text("設定")
            .bikeyFont(20, weight: .medium, relativeTo: .title3)
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity)
    }
}

private struct ThemeOptionCard: View {
    let option: AppThemePreference
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: option.iconName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isSelected ? AppColor.purple : AppColor.ink.opacity(0.72))
                Text(option.label)
                    .bikeyFont(13, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(isSelected ? AppColor.purple : AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .padding(.vertical, 10)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : AppColor.rule.opacity(0.4), lineWidth: isSelected ? 2 : 0.6)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ProfileCard: View {
    let displayName: String
    @ObservedObject var stats: ConversionStats
    let promptCount: Int

    var body: some View {
        ZStack {
            ProfileCardBackground()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: BikeyMetrics.Spacing.m - 4) {
                    ProfilePortrait()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        (displayName.isEmpty ? Text("敬語ボタンユーザー") : Text(verbatim: displayName))
                            .bikeyFont(18, weight: .regular, relativeTo: .title3)
                            .foregroundStyle(AppColor.ink.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)

                        Text("\(stats.conversionsDisplay)回書き直し")
                            .bikeyFont(12, weight: .regular, relativeTo: .caption)
                            .foregroundStyle(AppColor.muted)
                    }

                    Spacer()
                }

                HStack(spacing: 0) {
                    ProfileStat(value: stats.conversionsDisplay, label: "書き直し")
                    ProfileStat(value: "\(promptCount)", label: "プロンプト")
                    ProfileStat(value: stats.streakDisplay, label: "日連続")
                }
                .padding(.top, BikeyMetrics.Spacing.m)

                Rectangle()
                    .fill(AppColor.rule.opacity(0.55))
                    .frame(height: 1)
                    .padding(.top, BikeyMetrics.Spacing.s + 3)

                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: BikeyMetrics.Spacing.s + 3) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(AppColor.charcoalAction)
                            .frame(width: 27, height: 27)
                            .overlay {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("敬語ボタン")
                                .bikeyFont(16, weight: .bold, relativeTo: .body)
                                .foregroundStyle(AppColor.ink.opacity(0.92))

                            Text("通常入力は端末内で。AIはタップ時だけ。")
                                .bikeyFont(11, weight: .medium, relativeTo: .footnote)
                                .foregroundStyle(AppColor.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }

                    Spacer()
                }
                .padding(.top, BikeyMetrics.Spacing.s + 3)
            }
            .padding(.top, BikeyMetrics.Spacing.m)
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.bottom, BikeyMetrics.Spacing.s + 3)
        }
        .frame(height: 198)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

private struct ProfileCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let image = ProfileBundledImage.load(colorScheme == .dark ? "globebg-dark" : "globebg") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.12)
            } else {
                LinearGradient(
                    colors: [
                        AppColor.lavender,
                        AppColor.paleLavender
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private enum ProfileBundledImage {
    static func load(_ name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/\(name).png").path)
    }
}

private struct ProfilePortrait: View {
    var body: some View {
        Circle()
            .fill(AppColor.surface.opacity(0.92))
            .overlay {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(
                        Color(red: 0.230, green: 0.226, blue: 0.255).opacity(0.88),
                        Color(red: 0.930, green: 0.925, blue: 0.918)
                    )
            }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .bikeyFont(15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(AppColor.ink)

            Text(label)
                .bikeyFont(11, weight: .medium, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .bikeyFont(18, weight: .regular, relativeTo: .headline)
            .foregroundStyle(Color(red: 0.475, green: 0.468, blue: 0.512))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, BikeyMetrics.Spacing.s + 2)
    }
}

private struct ProfileListCard: View {
    let rows: [ProfileRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ProfileListRow(model: row)

                if index < rows.count - 1 {
                    Divider()
                        .overlay(Color.black.opacity(0.035))
                        .padding(.leading, 56)
                        .padding(.trailing, BikeyMetrics.Spacing.m)
                }
            }
        }
        .background(AppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}

private struct ProfileRowModel {
    let icon: String
    let title: LocalizedStringKey
    let trailing: LocalizedStringKey?
    let isDestructive: Bool
    let highlight: Bool
    let action: (() -> Void)?
    let toggle: Binding<Bool>?

    init(
        icon: String,
        title: LocalizedStringKey,
        trailing: LocalizedStringKey? = nil,
        isDestructive: Bool = false,
        highlight: Bool = false,
        action: (() -> Void)? = nil,
        toggle: Binding<Bool>? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.isDestructive = isDestructive
        self.highlight = highlight
        self.action = action
        self.toggle = toggle
    }
}

private struct ProfileListRow: View {
    let model: ProfileRowModel

    var body: some View {
        if let action = model.action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        let destructive = Color(red: 0.847, green: 0.306, blue: 0.345)
        return HStack(spacing: BikeyMetrics.Spacing.m - 3) {
            Image(systemName: model.icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(model.isDestructive ? destructive : AppColor.ink.opacity(0.86))
                .frame(width: 22)

            Text(model.title)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(model.isDestructive ? destructive : AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if let toggle = model.toggle {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .tint(AppColor.purple)
            }

            if let trailing = model.trailing {
                Text(trailing)
                    .bikeyFont(14, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.muted.opacity(0.82))
            }

            if model.action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColor.muted.opacity(0.82))
            }
        }
        .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
        .frame(minHeight: 54)
        .background {
            if model.highlight {
                ShimmerRowBackground()
            }
        }
        .contentShape(Rectangle())
    }
}

struct ShimmerRowBackground: View {
    @State private var phase: CGFloat = -1
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: AppColor.purple.opacity(0.0), location: 0.0),
                    .init(color: AppColor.purple.opacity(0.12), location: 0.5),
                    .init(color: AppColor.purple.opacity(0.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.55)
            .offset(x: phase * width)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.6
            }
        }
    }
}

struct AIConsentInfoModal: View {
    let onClose: () -> Void

    @AppStorage(KeyboardSettingsStore.aiConsentGrantedKey, store: KeyboardSettingsStore.sharedDefaults)
    private var consentGranted = false

    @State private var showPrivacy = false
    @State private var agreedToPolicy = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                VStack(spacing: BikeyMetrics.Spacing.m) {
                    hero
                    AIConsentCompactSummary()
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l - 2)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.s)

                consentAction
                    .padding(.horizontal, BikeyMetrics.Spacing.m)
                    .padding(.top, BikeyMetrics.Spacing.xs)
                    .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 348)
            .fixedSize(horizontal: false, vertical: true)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: LegalLinks.privacy)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(consentGranted ? AppColor.purple.opacity(0.10) : Color.black.opacity(0.06))
                    .frame(width: 48, height: 48)

                Image(systemName: consentGranted ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(consentGranted ? AppColor.purple : AppColor.charcoalAction)
            }

            Text(consentGranted ? "AI変換は有効です" : "AIに送る前に\n確認してください")
                .bikeyFont(22, weight: .medium, relativeTo: .title2)
                .foregroundStyle(AppColor.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(consentGranted ? "敬語ボタンを押した時だけ、その文章がAIサービスに送信されます。設定はいつでもここから変更できます。" : "敬語ボタンを押した時だけ、その文章がAIサービスに送信されます。通常の入力が送信されることはありません。")
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(AppColor.muted.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var consentAction: some View {
        if consentGranted {
            VStack(spacing: 10) {
                Button {
                    consentGranted = false
                    agreedToPolicy = false
                    onClose()
                } label: {
                    Text("AI変換を無効にする")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(Color(red: 0.847, green: 0.306, blue: 0.345))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColor.surface, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.847, green: 0.306, blue: 0.345).opacity(0.34), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onClose()
                } label: {
                    Text("閉じる")
                        .bikeyFont(14, weight: .regular, relativeTo: .body)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 12) {
                ProfileConsentAgreementCheckbox(
                    isOn: $agreedToPolicy,
                    onOpenPrivacy: { showPrivacy = true }
                )

                Button {
                    consentGranted = true
                    onClose()
                } label: {
                    Text("同意して有効にする")
                        .bikeyFont(16, weight: .medium, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Capsule().fill(AppColor.charcoalAction.opacity(agreedToPolicy ? 1 : 0.42)))
                }
                .buttonStyle(.plain)
                .disabled(!agreedToPolicy)
                .accessibilityHint(agreedToPolicy ? Text("") : Text("プライバシーポリシーへの同意が必要です"))

                Button(action: onClose) {
                    Text("今は使わない")
                        .bikeyFont(14, weight: .regular, relativeTo: .body)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct HapticsFullAccessRequiredModal: View {
    let onCancel: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColor.purple.opacity(0.10))
                        .frame(width: 58, height: 58)
                    Image(systemName: "hand.tap")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AppColor.purple)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("フルアクセスが必要です")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("触覚フィードバックを使うには、iOS設定で敬語ボタンのフルアクセスをオンにしてください。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                VStack(spacing: 8) {
                    Button(action: onOpenSettings) {
                        Text("設定を開く")
                            .bikeyFont(15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.charcoalAction, in: Capsule())
                            .shadow(color: AppColor.charcoalAction.opacity(0.22), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text("あとで")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.surface, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.rule.opacity(0.45), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 320)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}

private struct AIConsentCompactSummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIサービスに送信される内容")
                .bikeyFont(13, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)

            AIConsentDataRow(icon: "text.alignleft", text: "敬語ボタンを押した時のテキスト")
            AIConsentDataRow(icon: "cpu", text: "送信先：第三者のAIサービス")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AIConsentDataRow: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColor.ink)
                .frame(width: 22)

            Text(text)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(AppColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct ProfileConsentAgreementCheckbox: View {
    @Binding var isOn: Bool
    let onOpenPrivacy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? AppColor.charcoalAction : AppColor.surface)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isOn ? Color.clear : AppColor.rule.opacity(0.72), lineWidth: 1.5)
                        )

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("プライバシーポリシーの内容に同意する")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])

            Text(.init("[プライバシーポリシー](\(LegalLinks.privacy.absoluteString))の内容に同意します"))
                .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink)
                .tint(AppColor.purple)
                .environment(\.openURL, OpenURLAction { _ in
                    onOpenPrivacy()
                    return .handled
                })
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, BikeyMetrics.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct SignOutConfirmModal: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private let destructive = Color(red: 0.847, green: 0.306, blue: 0.345)

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 58, height: 58)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AppColor.ink)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("サインアウトしますか？")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("保存したプロンプトや設定を使うには、もう一度サインインが必要です。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                VStack(spacing: 8) {
                    Button(action: onConfirm) {
                        Text("サインアウト")
                            .bikeyFont(15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(destructive, in: Capsule())
                            .shadow(color: destructive.opacity(0.28), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text("キャンセル")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.surface, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.rule.opacity(0.45), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 320)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}

struct DeleteAccountConfirmModal: View {
    let isDeleting: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private let destructive = Color(red: 0.847, green: 0.306, blue: 0.345)

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if !isDeleting { onCancel() } }

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(destructive.opacity(0.10))
                        .frame(width: 58, height: 58)
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(destructive)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("アカウントを削除しますか？")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("アカウント、保存したプロンプト、変換履歴を完全に削除します。この操作は取り消せません。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                if let errorMessage {
                    Text(errorMessage)
                        .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(destructive)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, BikeyMetrics.Spacing.s)
                        .padding(.horizontal, BikeyMetrics.Spacing.l)
                }

                VStack(spacing: 8) {
                    Button(action: onConfirm) {
                        ZStack {
                            Text("アカウントを削除")
                                .bikeyFont(15, weight: .semibold, relativeTo: .body)
                                .foregroundStyle(.white)
                                .opacity(isDeleting ? 0 : 1)
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(destructive, in: Capsule())
                        .shadow(color: destructive.opacity(0.28), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)

                    Button(action: onCancel) {
                        Text("キャンセル")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.surface, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.rule.opacity(0.45), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 320)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}

private struct KeyboardStylePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: KeyboardPreferences.KeyboardStyle

    var body: some View {
        ScrollView {
            VStack(spacing: BikeyMetrics.Spacing.l) {
                HStack(spacing: BikeyMetrics.Spacing.m) {
                    ForEach(InputStyleOption.selectable, id: \.self) { style in
                        InputStyleSelectionCard(
                            style: style,
                            isSelected: selection == style,
                            onTap: {
                                selection = style
                                KeyboardSettingsStore.writeKeyboardStyle(style)
                            }
                        )
                    }
                }

                Text("入力方式はいつでも変更できます。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
            .padding(.top, BikeyMetrics.Spacing.l)
        }
        .background(AppColor.canvas.ignoresSafeArea())
        .navigationTitle("キーボード入力方式")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BikeyNavigationBackButton { dismiss() }
            }
        }
    }
}
