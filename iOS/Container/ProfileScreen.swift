import KeyboardPreferences
import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject private var session: UserSession
    @EnvironmentObject private var overlay: AppOverlay
    @ObservedObject private var stats = ConversionStats.shared
    @State private var showPersonalInfo = false
    @State private var promptCount: Int = UserPromptStore.readEntries().count
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
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "サインアウト",
                                action: { overlay.present(.signOut) }
                            ),
                            .init(
                                icon: "trash",
                                title: "アカウントを削除",
                                isDestructive: true,
                                action: { overlay.present(.deleteAccount) }
                            )
                        ]
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileSectionTitle("その他")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
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
            .navigationDestination(isPresented: $showAbout) {
                AboutScreen()
            }
            .onAppear {
                KeyboardSettingsStore.writeCloudAIEnabled(true)
                promptCount = UserPromptStore.readEntries().count
            }
            .onChange(of: session.profile) { _ in
                KeyboardSettingsStore.writeCloudAIEnabled(true)
                promptCount = UserPromptStore.readEntries().count
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
                        Text(displayName.isEmpty ? "敬語ボタンユーザー" : displayName)
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
    var body: some View {
        Group {
            if let image = ProfileBundledImage.load("globebg") {
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
        .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}

private struct ProfileRowModel {
    let icon: String
    let title: String
    let trailing: String?
    let isDestructive: Bool
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        trailing: String? = nil,
        isDestructive: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.isDestructive = isDestructive
        self.action = action
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

            if let trailing = model.trailing {
                Text(trailing)
                    .bikeyFont(14, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.muted.opacity(0.82))
            }

            if model.action != nil {
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
