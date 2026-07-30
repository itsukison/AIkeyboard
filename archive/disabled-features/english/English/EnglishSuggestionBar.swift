import SwiftUI

/// QuickType-style English suggestion bar shown as the keyboard toolbar in
/// English mode. Native look only — no Bikey design tokens on the keyboard
/// surface. Shows up to three suggestions; tapping one accepts it.
struct EnglishSuggestionBar: View {
    @ObservedObject var controller: EnglishInputController
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            let shown = Array(controller.suggestions.prefix(3).enumerated())
            if shown.isEmpty {
                Color.clear
            } else {
                ForEach(shown, id: \.offset) { index, word in
                    if index > 0 {
                        Divider()
                            .frame(height: 24)
                            .opacity(0.5)
                    }
                    Button {
                        onSelect(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}
