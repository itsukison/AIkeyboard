import KeyboardKit
import KeyboardPreferences
import SwiftUI
import UIKit

struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var overlay: AppOverlay
    @AppStorage(KeyboardSettingsStore.aiConsentGrantedKey, store: KeyboardSettingsStore.sharedDefaults)
    private var consentGranted = false
    @State private var activeURL: IdentifiedURL?
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                AboutHeader()
                    .padding(.top, BikeyMetrics.Spacing.l)

                AboutListCard(
                    rows: [
                        AboutRowModel(
                            icon: "wand.and.stars",
                            title: "AI変換とプライバシー",
                            highlight: !consentGranted
                        ) {
                            overlay.present(.aiConsent)
                        },
                        AboutRowModel(
                            icon: "lock.shield",
                            title: "フルアクセス",
                            trailing: keyboardStatus.isFullAccessEnabled ? "オン" : "オフ",
                            highlight: !keyboardStatus.isFullAccessEnabled
                        ) {
                            openSystemSettings()
                        },
                        AboutRowModel(icon: "questionmark.circle", title: "サポート") {
                            activeURL = IdentifiedURL(url: LegalLinks.support)
                        },
                        AboutRowModel(icon: "hand.raised", title: "プライバシーポリシー") {
                            activeURL = IdentifiedURL(url: LegalLinks.privacy)
                        },
                        AboutRowModel(icon: "doc.text", title: "利用規約") {
                            activeURL = IdentifiedURL(url: LegalLinks.terms)
                        },
                        AboutRowModel(
                            icon: "envelope",
                            title: "お問い合わせ",
                            trailing: LegalLinks.contactEmail,
                            showsChevron: false
                        ) {
                            openURL(LegalLinks.contactMailto)
                        }
                    ]
                )
                .padding(.top, BikeyMetrics.Spacing.l)

                Text("© 2026 敬語ボタン")
                    .bikeyFont(11, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.muted)
                    .padding(.top, BikeyMetrics.Spacing.xl)

                Spacer(minLength: BikeyMetrics.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BikeyNavigationBackButton { dismiss() }
            }
        }
        .sheet(item: $activeURL) { SafariView(url: $0.url) }
        .onAppear {
            keyboardStatus.refresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                keyboardStatus.refresh()
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct AboutHeader: View {
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "バージョン \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: BikeyMetrics.Spacing.s) {
            AboutLogoTile()
                .frame(width: 72, height: 72)

            Text("敬語ボタン")
                .bikeyFont(20, weight: .medium, relativeTo: .title3)
                .foregroundStyle(AppColor.ink)
                .padding(.top, BikeyMetrics.Spacing.s)

            Text(versionString)
                .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AboutLogoTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColor.paleLavender)
            .overlay {
                if let image = AboutBundledImage.load("applogo") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AppColor.purple.opacity(0.22), radius: 12, x: 0, y: 6)
    }
}

private enum AboutBundledImage {
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

private struct AboutRowModel {
    let icon: String
    let title: String
    let trailing: String?
    let showsChevron: Bool
    let highlight: Bool
    let action: () -> Void

    init(
        icon: String,
        title: String,
        trailing: String? = nil,
        showsChevron: Bool = true,
        highlight: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.showsChevron = showsChevron
        self.highlight = highlight
        self.action = action
    }
}

private struct AboutListCard: View {
    let rows: [AboutRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                AboutListRow(model: row)

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

private struct AboutListRow: View {
    let model: AboutRowModel

    var body: some View {
        Button(action: model.action) {
            HStack(spacing: BikeyMetrics.Spacing.m - 3) {
                Image(systemName: model.icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(AppColor.ink.opacity(0.86))
                    .frame(width: 22)

                Text(model.title)
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                if let trailing = model.trailing {
                    Text(trailing)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if model.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.34))
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
        .buttonStyle(.plain)
    }
}
