import KeyboardPreferences
import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject private var session: UserSession
    @ObservedObject private var stats = ConversionStats.shared
    @State private var keyboardStyle = KeyboardSettingsStore.readKeyboardStyle()
    @State private var hapticsEnabled = KeyboardSettingsStore.readHapticsEnabled()
    @State private var cloudAIEnabled = KeyboardSettingsStore.readCloudAIEnabled()
    @State private var fullAccessEnabled = KeyboardSettingsStore.readLastKnownFullAccessEnabled()
    @State private var showPersonalInfo = false
    @State private var promptCount: Int = UserPromptStore.readEntries().count
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage: String?
    @State private var showKeyboardStyleInfo = false
    @State private var showAIPrivacy = false
    @State private var showAbout = false

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

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "person",
                                title: "ユーザー情報",
                                action: { showPersonalInfo = true }
                            ),
                            .init(
                                icon: "character.cursor.ibeam",
                                title: "「ー」キーを表示",
                                toggle: .keyboardStyle,
                                infoAction: {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        showKeyboardStyleInfo = true
                                    }
                                }
                            ),
                            .init(
                                icon: "hand.tap",
                                title: "触覚フィードバック",
                                toggle: .haptics
                            ),
                            .init(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "サインアウト",
                                action: { showSignOutConfirm = true }
                            ),
                            .init(
                                icon: "trash",
                                title: "アカウントを削除",
                                isDestructive: true,
                                action: { showDeleteAccountConfirm = true }
                            )
                        ],
                        keyboardStyle: $keyboardStyle,
                        hapticsEnabled: $hapticsEnabled
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileSectionTitle("AI機能")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "wand.and.sparkles",
                                title: "クラウドAI",
                                toggle: .cloudAI
                            ),
                            .init(
                                icon: "keyboard",
                                title: "フルアクセス",
                                trailing: fullAccessEnabled ? "オン" : "オフ"
                            ),
                            .init(
                                icon: "hand.raised",
                                title: "プライバシー",
                                action: { showAIPrivacy = true }
                            )
                        ],
                        cloudAIEnabled: $cloudAIEnabled
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileSectionTitle("その他")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "info.circle",
                                title: "AIキーボードについて",
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
            .navigationDestination(isPresented: $showAIPrivacy) {
                AIRewritePrivacyView()
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutScreen()
            }
            .onAppear {
                keyboardStyle = KeyboardSettingsStore.readKeyboardStyle()
                cloudAIEnabled = KeyboardSettingsStore.readCloudAIEnabled()
                fullAccessEnabled = KeyboardSettingsStore.readLastKnownFullAccessEnabled()
                promptCount = UserPromptStore.readEntries().count
            }
            .onChange(of: session.profile) { _ in
                keyboardStyle = KeyboardSettingsStore.readKeyboardStyle()
                cloudAIEnabled = KeyboardSettingsStore.readCloudAIEnabled()
                fullAccessEnabled = KeyboardSettingsStore.readLastKnownFullAccessEnabled()
                promptCount = UserPromptStore.readEntries().count
            }
            .overlay {
                if showSignOutConfirm {
                    SignOutConfirmModal(
                        onCancel: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showSignOutConfirm = false
                            }
                        },
                        onConfirm: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showSignOutConfirm = false
                            }
                            Task { await session.signOut() }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
                if showDeleteAccountConfirm {
                    DeleteAccountConfirmModal(
                        isDeleting: isDeletingAccount,
                        errorMessage: deleteAccountErrorMessage,
                        onCancel: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showDeleteAccountConfirm = false
                                deleteAccountErrorMessage = nil
                            }
                        },
                        onConfirm: {
                            deleteAccountErrorMessage = nil
                            isDeletingAccount = true
                            Task {
                                defer { isDeletingAccount = false }
                                do {
                                    try await session.deleteAccount()
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        showDeleteAccountConfirm = false
                                    }
                                } catch {
                                    deleteAccountErrorMessage = error.localizedDescription
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
                if showKeyboardStyleInfo {
                    KeyboardStyleInfoModal(
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showKeyboardStyleInfo = false
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }
            }
            .animation(.easeOut(duration: 0.18), value: showSignOutConfirm)
            .animation(.easeOut(duration: 0.18), value: showDeleteAccountConfirm)
            .animation(.easeOut(duration: 0.18), value: showKeyboardStyleInfo)
            .onChange(of: hapticsEnabled) { newValue in
                KeyboardSettingsStore.writeHapticsEnabled(newValue)
            }
            .onChange(of: keyboardStyle) { newValue in
                KeyboardSettingsStore.writeKeyboardStyle(newValue)
            }
            .onChange(of: cloudAIEnabled) { newValue in
                KeyboardSettingsStore.writeCloudAIEnabled(newValue)
            }
        }
    }
}

private struct PersonalInformationView: View {
    let profile: UserSession.Profile?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s + 2) {
                infoRow(label: "名前", value: profile?.displayName ?? "—")
                infoRow(label: "メール", value: profile?.email ?? "—")
                infoRow(
                    label: "登録日",
                    value: profile.map { Self.dateFormatter.string(from: $0.createdAt) } ?? "—"
                )
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.top, BikeyMetrics.Spacing.l - 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("ユーザー情報")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)
            Text(value)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(AppColor.ink)
        }
        .padding(.vertical, BikeyMetrics.Spacing.s - 1)
        .padding(.horizontal, BikeyMetrics.Spacing.m - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct AIRewritePrivacyView: View {
    private let rows = [
        "AI機能は、AIコマンドをタップした時だけ文章を送信します。",
        "通常の入力中に、すべてのキー入力を送ることはありません。",
        "クラウドAIをオフにしても、日本語入力は使えます。",
        "クラウドAIには、iOSの仕様上「フルアクセスを許可」が必要です。"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s + 2) {
                ForEach(rows, id: \.self) { text in
                    HStack(alignment: .top, spacing: BikeyMetrics.Spacing.s + 2) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(AppColor.purple.opacity(0.78))
                            .frame(width: 22)

                        Text(text)
                            .bikeyFont(15, weight: .regular, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
                    .padding(.vertical, BikeyMetrics.Spacing.s + 2)
                }
            }
            .padding(.vertical, BikeyMetrics.Spacing.m)
            .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
            .padding(.top, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("AI機能")
        .navigationBarTitleDisplayMode(.inline)
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
                        Text(displayName.isEmpty ? "AIキーボードユーザー" : displayName)
                            .bikeyFont(20, weight: .regular, relativeTo: .title2)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)

                        Text("AIキーボードで\n\(stats.conversionsDisplay)回変換")
                            .bikeyFont(12, weight: .regular, relativeTo: .caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(3)
                    }

                    Spacer()
                }

                HStack(spacing: 0) {
                    ProfileStat(value: stats.conversionsDisplay, label: "変換")
                    ProfileStat(value: "\(promptCount)", label: "プロンプト")
                    ProfileStat(value: stats.streakDisplay, label: "日連続")
                }
                .padding(.top, BikeyMetrics.Spacing.l + 1)

                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(height: 1)
                    .padding(.top, BikeyMetrics.Spacing.m + 2)

                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: BikeyMetrics.Spacing.s + 3) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white.opacity(0.20))
                            .frame(width: 27, height: 27)
                            .overlay {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("AIキーボード")
                                .bikeyFont(16, weight: .semibold, relativeTo: .body)
                                .foregroundStyle(.white)

                            Text("通常入力は端末内で。\nAIは必要な時だけ。")
                                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                                .foregroundStyle(.white.opacity(0.76))
                                .lineSpacing(3)
                        }
                    }

                    Spacer()
                }
                .padding(.top, BikeyMetrics.Spacing.m + 2)
            }
            .padding(.top, BikeyMetrics.Spacing.l - 4)
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.bottom, BikeyMetrics.Spacing.m + 2)
        }
        .frame(height: 247)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppColor.purple.opacity(0.18), radius: 12, x: 0, y: 7)
    }
}

private struct ProfileCardBackground: View {
    var body: some View {
        ZStack {
            if let image = loadHeroImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.552, green: 0.458, blue: 0.795),
                        Color(red: 0.720, green: 0.656, blue: 0.895)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.black.opacity(0.22), .black.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func loadHeroImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "gradient2", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/gradient2.png").path)
    }
}

private struct ProfilePortrait: View {
    var body: some View {
        Circle()
            .fill(.white.opacity(0.92))
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
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(.white)

            Text(label)
                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileSectionTitle: View {
    let title: String

    init(_ title: String) {
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
    var keyboardStyle: Binding<KeyboardStyle>? = nil
    var hapticsEnabled: Binding<Bool>? = nil
    var cloudAIEnabled: Binding<Bool>? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ProfileListRow(
                    model: row,
                    keyboardStyle: keyboardStyle,
                    hapticsEnabled: hapticsEnabled,
                    cloudAIEnabled: cloudAIEnabled
                )

                if index < rows.count - 1 {
                    Divider()
                        .overlay(Color.black.opacity(0.035))
                        .padding(.leading, 56)
                        .padding(.trailing, BikeyMetrics.Spacing.m)
                }
            }
        }
        .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}

private struct ProfileRowModel {
    enum ToggleKind {
        case keyboardStyle
        case haptics
        case cloudAI
    }

    let icon: String
    let title: String
    let trailing: String?
    let toggle: ToggleKind?
    let isDestructive: Bool
    let infoAction: (() -> Void)?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        trailing: String? = nil,
        toggle: ToggleKind? = nil,
        isDestructive: Bool = false,
        infoAction: (() -> Void)? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.toggle = toggle
        self.isDestructive = isDestructive
        self.infoAction = infoAction
        self.action = action
    }
}

private struct ProfileListRow: View {
    let model: ProfileRowModel
    var keyboardStyle: Binding<KeyboardStyle>?
    var hapticsEnabled: Binding<Bool>?
    var cloudAIEnabled: Binding<Bool>?

    private var isJapaneseRomaji: Binding<Bool> {
        Binding(
            get: { keyboardStyle?.wrappedValue == .japaneseRomaji },
            set: { keyboardStyle?.wrappedValue = $0 ? .japaneseRomaji : .standard }
        )
    }

    var body: some View {
        if let action = model.action, model.toggle == nil {
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

            if let infoAction = model.infoAction {
                Button(action: infoAction) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(AppColor.muted.opacity(0.82))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(model.title)について")
            }

            Spacer()

            if model.toggle == .keyboardStyle, keyboardStyle != nil {
                Toggle("", isOn: isJapaneseRomaji)
                    .labelsHidden()
                    .tint(AppColor.purple.opacity(0.82))
            } else if model.toggle == .haptics, let hapticsEnabled {
                Toggle("", isOn: hapticsEnabled)
                    .labelsHidden()
                    .tint(AppColor.purple.opacity(0.82))
            } else if model.toggle == .cloudAI, let cloudAIEnabled {
                Toggle("", isOn: cloudAIEnabled)
                    .labelsHidden()
                    .tint(AppColor.purple.opacity(0.82))
            } else if let trailing = model.trailing {
                Text(trailing)
                    .bikeyFont(14, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.muted.opacity(0.82))
            }

            if model.toggle == nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.34))
            }
        }
        .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct SignOutConfirmModal: View {
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
                            .background(.white, in: Capsule())
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
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}

private struct KeyboardStyleInfoModal: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColor.paleLavender.opacity(0.92))
                        .frame(width: 58, height: 58)
                    Text("ー")
                        .bikeyFont(25, weight: .regular, relativeTo: .title2)
                        .foregroundStyle(AppColor.purple)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("「ー」キーを表示")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("ローマ字入力で使う長音記号を、Lキーの右に追加します。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                ProfileLongVowelKeyboardPreview()
                    .padding(.horizontal, BikeyMetrics.Spacing.m)
                    .padding(.top, BikeyMetrics.Spacing.l)

                Button(action: onDismiss) {
                    Text("閉じる")
                        .bikeyFont(15, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppColor.charcoalAction, in: Capsule())
                        .shadow(color: AppColor.charcoalAction.opacity(0.22), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 340)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}

private struct ProfileLongVowelKeyboardPreview: View {
    private let row1 = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let row2 = ["A", "S", "D", "F", "G", "H", "J", "K", "L", "ー"]
    private let row3 = ["Z", "X", "C", "V", "B", "N", "M"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(row1, id: \.self) { key in
                    ProfilePreviewKey(label: key)
                }
            }

            HStack(spacing: 4) {
                ForEach(row2, id: \.self) { key in
                    ProfilePreviewKey(
                        label: key,
                        isHighlighted: key == "ー"
                    )
                }
            }

            HStack(spacing: 4) {
                ProfilePreviewIconKey(systemName: "shift.fill")
                ForEach(row3, id: \.self) { key in
                    ProfilePreviewKey(label: key)
                }
                ProfilePreviewIconKey(systemName: "delete.left")
            }

            HStack(spacing: 4) {
                ProfilePreviewFixedKey(label: "123", width: 38)
                ProfilePreviewIconKey(systemName: "globe", width: 34)
                ProfilePreviewFixedKey(label: "空白", width: nil)
                ProfilePreviewFixedKey(label: "改行", width: 58)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.86, green: 0.87, blue: 0.89))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lの右にーキーがあるキーボードプレビュー")
    }
}

private struct ProfilePreviewKey: View {
    let label: String
    var isHighlighted = false

    var body: some View {
        Text(label)
            .bikeyFont(label == "ー" ? 16 : 11, weight: isHighlighted ? .semibold : .regular, relativeTo: .caption)
            .foregroundStyle(isHighlighted ? AppColor.purple : AppColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHighlighted ? AppColor.paleLavender : Color.white)
                    .shadow(color: .black.opacity(0.16), radius: 0, x: 0, y: 1)
            )
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(AppColor.purple.opacity(0.34), lineWidth: 1)
                }
            }
    }
}

private struct ProfilePreviewIconKey: View {
    let systemName: String
    var width: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppColor.ink)
            .frame(width: width, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.74, green: 0.76, blue: 0.78))
                    .shadow(color: .black.opacity(0.16), radius: 0, x: 0, y: 1)
            )
    }
}

private struct ProfilePreviewFixedKey: View {
    let label: String
    let width: CGFloat?

    var body: some View {
        Text(label)
            .bikeyFont(11, weight: .regular, relativeTo: .caption)
            .foregroundStyle(AppColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.16), radius: 0, x: 0, y: 1)
            )
    }
}

private struct DeleteAccountConfirmModal: View {
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
                            .background(.white, in: Capsule())
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
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}
