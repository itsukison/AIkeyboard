import SwiftUI
import UIKit

struct BikeyTextField<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let field: Field
    var focused: FocusState<Field?>.Binding

    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .return
    var isSecure: Bool = false
    var onSubmit: (() -> Void)? = nil

    @State private var isPasswordVisible: Bool = false

    private var isFocused: Bool { focused.wrappedValue == field }
    private var hasContent: Bool { !text.isEmpty }
    private var labelFloated: Bool { isFocused || hasContent }

    var body: some View {
        ZStack(alignment: .leading) {
            field_(
                placeholder: labelFloated ? "" : label,
                shouldRevealSecure: isPasswordVisible
            )
            floatingLabel
        }
        .padding(.horizontal, BikeyMetrics.Spacing.l)
        .frame(minHeight: BikeyMetrics.Sizing.inputHeight)
        .bikeyGlass(
            in: RoundedRectangle(cornerRadius: BikeyMetrics.Radius.field, style: .continuous),
            fallback: .white
        )
        .overlay(
            RoundedRectangle(cornerRadius: BikeyMetrics.Radius.field, style: .continuous)
                .stroke(
                    isFocused ? AppColor.purple.opacity(0.65) : Color.clear,
                    lineWidth: 1.4
                )
        )
        .overlay(alignment: .trailing) {
            trailingAccessory
                .padding(.trailing, BikeyMetrics.Spacing.m)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: labelFloated)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = field }
    }

    @ViewBuilder
    private func field_(placeholder: String, shouldRevealSecure: Bool) -> some View {
        let prompt = Text(placeholder).foregroundColor(AppColor.softText)
        Group {
            if isSecure && !shouldRevealSecure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .keyboardType(keyboardType)
        .textInputAutocapitalization(isSecure ? .never : autocapitalization)
        .autocorrectionDisabled(true)
        .textContentType(textContentType)
        .submitLabel(submitLabel)
        .focused(focused, equals: field)
        .foregroundStyle(AppColor.ink)
        .bikeyFont(17, weight: .regular)
        .padding(.top, labelFloated ? 14 : 0)
        .padding(.trailing, trailingPadding)
        .onSubmit { onSubmit?() }
    }

    private var trailingPadding: CGFloat {
        let showsClear = isFocused && hasContent && !isSecure
        let showsEye = isSecure
        return (showsClear || showsEye) ? 36 : 0
    }

    @ViewBuilder
    private var floatingLabel: some View {
        Text(label)
            .foregroundStyle(labelFloated ? AppColor.muted : AppColor.softText)
            .bikeyFont(labelFloated ? 12 : 17, weight: .regular, relativeTo: .caption)
            .padding(.bottom, labelFloated ? 26 : 0)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isSecure {
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColor.softText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "パスワードを隠す" : "パスワードを表示")
        } else if isFocused && hasContent {
            Button {
                text = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColor.softText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("入力内容を消去")
            .transition(.opacity)
        }
    }
}

struct BikeyKeyboardToolbar: ViewModifier {
    var dismissTitle: String = "完了"
    var onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(dismissTitle, action: onDismiss)
                    .foregroundStyle(AppColor.purple)
            }
        }
    }
}

extension View {
    func bikeyKeyboardToolbar(dismissTitle: String = "完了", onDismiss: @escaping () -> Void) -> some View {
        modifier(BikeyKeyboardToolbar(dismissTitle: dismissTitle, onDismiss: onDismiss))
    }
}
