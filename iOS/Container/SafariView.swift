import SafariServices
import SwiftUI

struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(AppColor.purple)
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
