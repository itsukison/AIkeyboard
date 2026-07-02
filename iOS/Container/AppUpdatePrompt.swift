import SwiftUI
import UIKit

/// Checks the App Store for a newer build via Apple's public iTunes Lookup API
/// and decides whether to surface the soft "please update" prompt. Container-only:
/// the keyboard extension must never make this (or any non-rewrite) network call.
enum AppUpdateChecker {
    struct UpdateInfo: Identifiable, Equatable {
        let latestVersion: String
        let appStoreURL: URL
        var id: String { latestVersion }
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let version: String
            let trackViewUrl: String
            let currentVersionReleaseDate: String
        }
        let results: [Result]
    }

    /// Returns update info only when the App Store version is strictly newer than
    /// the installed one AND has been live for at least a day. The Lookup API
    /// updates before the binary finishes propagating across App Store CDNs, so a
    /// same-day prompt can point users at a build they can't download yet.
    /// Returns nil on any failure — the check must never block the app.
    static func check() async -> UpdateInfo? {
        // JP storefront: this app ships only on the Japanese App Store, and a
        // US lookup returns no results, which would silently disable the prompt.
        guard let bundleId = Bundle.main.bundleIdentifier,
              var components = URLComponents(string: "https://itunes.apple.com/jp/lookup") else { return nil }
        components.queryItems = [URLQueryItem(name: "bundleId", value: bundleId)]

        guard let url = components.url,
              let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(LookupResponse.self, from: data),
              let result = response.results.first,
              let appStoreURL = URL(string: result.trackViewUrl),
              isVersion(result.version, newerThan: installed)
        else { return nil }

        if let released = ISO8601DateFormatter().date(from: result.currentVersionReleaseDate),
           Date().timeIntervalSince(released) < 24 * 60 * 60 {
            return nil
        }

        return UpdateInfo(latestVersion: result.version, appStoreURL: appStoreURL)
    }

    /// Numeric, component-wise compare ("1.0.10" is newer than "1.0.9"), padding
    /// the shorter side with zeros so "1.1" beats "1.0.9".
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

struct UpdateAvailableModal: View {
    let onUpdate: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onLater)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppColor.purple.opacity(0.10))
                        .frame(width: 58, height: 58)
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AppColor.purple)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("アップデートのお知らせ")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("新しいバージョンが利用可能です。最新版にアップデートすると、最新の機能と改善をご利用いただけます。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                VStack(spacing: 8) {
                    Button(action: onUpdate) {
                        Text("アップデート")
                            .bikeyFont(15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.charcoalAction, in: Capsule())
                            .shadow(color: AppColor.charcoalAction.opacity(0.22), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button(action: onLater) {
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
