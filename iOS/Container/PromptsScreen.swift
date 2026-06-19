import KeyboardPreferences
import PostHog
import SwiftUI
import UIKit

struct PromptsScreen: View {
    @EnvironmentObject private var session: UserSession
    @State private var entries: [UserPrompt] = UserPromptStore.readEntries()
    @State private var editorPayload: PromptEditorPayload?
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showAuth = false

    private var isGuest: Bool { session.profile == nil }

    private func openEditor(_ entry: UserPrompt) {
        if isGuest {
            showAuth = true
        } else {
            editorPayload = .existing(entry)
        }
    }

    private var mainEntry: UserPrompt? {
        entries.first(where: { $0.slot == .main })
    }

    private var subEntries: [UserPrompt] {
        entries.filter { $0.slot == .sub }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColor.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                        PromptsHeader()
                            .padding(.top, BikeyMetrics.Spacing.s)

                        if isGuest {
                            GuestPromptsCTA { showAuth = true }
                        }

                        if let errorMessage {
                            PromptsNotice(
                                text: errorMessage,
                                systemName: "exclamationmark.circle",
                                tint: AppColor.purple
                            )
                        }

                        sectionTitle("メインボタン")
                        mainCard

                        sectionTitle("追加ボタン")
                        subCard

                        Spacer(minLength: BikeyMetrics.Sizing.tabBarHeight + 100)
                    }
                    .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
                }

                if !isGuest {
                    PromptsFloatingActionButton {
                        editorPayload = .newCustom(nextSortOrder: nextSortOrder())
                    }
                    .padding(.trailing, BikeyMetrics.Sizing.screenHorizontalInset)
                    .padding(.bottom, BikeyMetrics.Sizing.tabBarHeight + 18)
                }
            }
            .navigationBarHidden(true)
            .editorSheet(item: $editorPayload) { payload in
                PromptEditor(
                    payload: payload,
                    onSave: { title, prompt, isEnabled in
                        await savePrompt(payload: payload, title: title, prompt: prompt, isEnabled: isEnabled)
                    },
                    onReset: { resetPayload in
                        await resetPrompt(resetPayload)
                    },
                    onDelete: payload.entry?.builtinKey == nil ? { entry in
                        await deletePrompt(entry: entry)
                    } : nil
                )
            }
            .task {
                await refreshEntries()
            }
            .onChange(of: session.profile) { _ in
                entries = UserPromptStore.readEntries()
            }
            .guestAuthCover(isPresented: $showAuth)
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .bikeyFont(13, weight: .medium, relativeTo: .footnote)
            .foregroundStyle(AppColor.muted)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private var mainCard: some View {
        VStack(spacing: 0) {
            if let mainEntry {
                PromptRow(entry: mainEntry) {
                    openEditor(mainEntry)
                }
            } else {
                Text("敬語プロンプトが読み込まれていません")
                    .bikeyFont(14, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.muted)
                    .padding(BikeyMetrics.Spacing.m)
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    @ViewBuilder
    private var subCard: some View {
        if subEntries.isEmpty {
            VStack(spacing: BikeyMetrics.Spacing.s) {
                Text("よく使うプロンプトを追加すると、キーボードの「…」から呼び出せます。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .padding(BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(subEntries.enumerated()), id: \.element.id) { index, entry in
                    PromptRow(entry: entry) {
                        openEditor(entry)
                    }

                    if index < subEntries.count - 1 {
                        Rectangle()
                            .fill(AppColor.rule.opacity(0.35))
                            .frame(height: 0.5)
                            .padding(.leading, BikeyMetrics.Spacing.m + 4)
                    }
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        }
    }

    private func nextSortOrder() -> Int {
        (subEntries.map(\.sortOrder).max() ?? -1) + 1
    }

    private func refreshEntries() async {
        entries = UserPromptStore.readEntries()
        guard session.profile != nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await session.refreshUserPromptsCache()
            entries = UserPromptStore.readEntries()
            errorMessage = nil
        } catch {
            errorMessage = "プロンプトを同期できませんでした。"
        }
    }

    private func savePrompt(
        payload: PromptEditorPayload,
        title: String,
        prompt: String,
        isEnabled: Bool
    ) async -> String? {
        guard let profile = session.profile else { return "サインインが必要です。" }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedPrompt.isEmpty else {
            return "タイトルとプロンプトを入力してください。"
        }
        guard trimmedPrompt.count <= 1000 else {
            return "プロンプトは1000文字以内で入力してください。"
        }

        isSyncing = true
        defer { isSyncing = false }
        do {
            if let entry = payload.entry {
                try await UserPromptRemoteStore.updatePrompt(
                    id: entry.id,
                    title: trimmedTitle,
                    prompt: trimmedPrompt,
                    isEnabled: isEnabled,
                    sortOrder: entry.sortOrder,
                    userId: profile.id
                )
                PostHogSDK.shared.capture("prompt_updated", properties: [
                    "is_builtin": entry.builtinKey != nil,
                ])
            } else {
                _ = try await UserPromptRemoteStore.insertCustomSubPrompt(
                    title: trimmedTitle,
                    prompt: trimmedPrompt,
                    sortOrder: nextSortOrder(),
                    userId: profile.id
                )
                PostHogSDK.shared.capture("prompt_created")
            }
            try await session.refreshUserPromptsCache()
            entries = UserPromptStore.readEntries()
            editorPayload = nil
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return nil
        } catch {
            let message = "保存できませんでした。"
            errorMessage = message
            return message
        }
    }

    private func resetPrompt(_ payload: PromptEditorPayload) async -> (title: String, prompt: String)? {
        guard let entry = payload.entry, let key = entry.builtinKey else { return nil }
        guard
            let defaultTitle = UserPromptDefaults.defaultTitle(for: key),
            let defaultPrompt = UserPromptDefaults.defaultPrompt(for: key)
        else { return nil }
        return (title: defaultTitle, prompt: defaultPrompt)
    }

    private func deletePrompt(entry: UserPrompt) async -> String? {
        guard let profile = session.profile else { return "サインインが必要です。" }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await UserPromptRemoteStore.deletePrompt(id: entry.id, userId: profile.id)
            PostHogSDK.shared.capture("prompt_deleted")
            try await session.refreshUserPromptsCache()
            entries = UserPromptStore.readEntries()
            editorPayload = nil
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return nil
        } catch {
            let message = "削除できませんでした。"
            errorMessage = message
            return message
        }
    }
}

// MARK: - Editor payload

struct PromptEditorPayload: Identifiable {
    let id = UUID()
    let entry: UserPrompt?
    let isNewCustom: Bool
    let nextSortOrder: Int?

    static func existing(_ entry: UserPrompt) -> PromptEditorPayload {
        PromptEditorPayload(entry: entry, isNewCustom: false, nextSortOrder: nil)
    }

    static func newCustom(nextSortOrder: Int) -> PromptEditorPayload {
        PromptEditorPayload(entry: nil, isNewCustom: true, nextSortOrder: nextSortOrder)
    }
}

// MARK: - Guest CTA

private struct GuestPromptsCTA: View {
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: BikeyMetrics.Spacing.m - 2) {
            VStack(spacing: 6) {
                Text("プロンプトを編集・追加するには")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)

                Text("サインインすると、メインボタンや追加ボタンを自由にカスタマイズして同期できます。")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onSignIn) {
                Text("サインイン / アカウント作成")
                    .bikeyFont(14, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(BikeyMetrics.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Header

private struct PromptsHeader: View {
    var body: some View {
        Text("プロンプト")
            .bikeyFont(20, weight: .medium, relativeTo: .title3)
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
    }
}

// MARK: - Row

private struct PromptRow: View {
    let entry: UserPrompt
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .bikeyFont(17, weight: .medium, relativeTo: .body)
                            .foregroundStyle(entry.isEnabled ? AppColor.ink : AppColor.softText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        if !entry.isEnabled {
                            Text("オフ")
                                .bikeyFont(11, weight: .regular, relativeTo: .caption)
                                .foregroundStyle(AppColor.softText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColor.rule.opacity(0.35), in: Capsule())
                        }
                    }

                    Text(entry.prompt)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.84)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColor.softText)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m + 4)
            .padding(.vertical, BikeyMetrics.Spacing.m - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PromptRowButtonStyle())
    }
}

private struct PromptRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? AppColor.lavender.opacity(0.45)
                    : Color.clear
            )
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

// MARK: - Floating action button

private struct PromptsFloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppColor.charcoalAction, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("プロンプトを追加")
    }
}

// MARK: - Notice

private struct PromptsNotice: View {
    let text: String
    let systemName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .bikeyFont(12, weight: .regular, relativeTo: .footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Editor bottom sheet

private enum EditorField: Hashable {
    case title
    case prompt
}

private let titleCharLimit = 24
private let promptCharLimit = 1000

private struct PromptEditor: View {
    let payload: PromptEditorPayload
    let onSave: (String, String, Bool) async -> String?
    let onReset: (PromptEditorPayload) async -> (title: String, prompt: String)?
    let onDelete: ((UserPrompt) async -> String?)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var prompt: String
    @State private var isEnabled: Bool
    @State private var isSaving = false
    @State private var validationMessage: String?
    @FocusState private var focusedField: EditorField?

    init(
        payload: PromptEditorPayload,
        onSave: @escaping (String, String, Bool) async -> String?,
        onReset: @escaping (PromptEditorPayload) async -> (title: String, prompt: String)?,
        onDelete: ((UserPrompt) async -> String?)?
    ) {
        self.payload = payload
        self.onSave = onSave
        self.onReset = onReset
        self.onDelete = onDelete
        _title = State(initialValue: payload.entry?.title ?? "")
        _prompt = State(initialValue: payload.entry?.prompt ?? "")
        _isEnabled = State(initialValue: payload.entry?.isEnabled ?? true)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && prompt.count <= promptCharLimit
    }

    private var isBuiltin: Bool {
        payload.entry?.builtinKey != nil
    }

    private var canDisable: Bool {
        // Allow disabling sub-buttons. The main button (keigo) must stay enabled.
        payload.entry?.slot != .main
    }

    private var screenTitle: String {
        if payload.isNewCustom { return "カスタムプロンプト" }
        return payload.entry?.title ?? "プロンプト"
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(
                cancelAction: { dismiss() },
                saveAction: {
                    Task {
                        guard !isSaving, canSave else { return }
                        isSaving = true
                        validationMessage = await onSave(title, prompt, isEnabled)
                        isSaving = false
                    }
                },
                isSaveEnabled: canSave && !isSaving,
                isSaving: isSaving
            )
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    Text(screenTitle)
                        .bikeyFont(22, weight: .semibold, relativeTo: .title2)
                        .foregroundStyle(AppColor.ink)
                        .padding(.top, 8)

                    EditorTitleField(
                        text: $title,
                        focused: $focusedField
                    )

                    EditorPromptField(
                        text: $prompt,
                        focused: $focusedField
                    )

                    if canDisable {
                        Toggle(isOn: $isEnabled) {
                            Text("有効にする")
                                .bikeyFont(14, weight: .medium, relativeTo: .body)
                                .foregroundStyle(AppColor.ink)
                        }
                        .tint(AppColor.purple.opacity(0.82))
                        .padding(.horizontal, 4)
                    }

                    if let validationMessage {
                        PromptsNotice(
                            text: validationMessage,
                            systemName: "exclamationmark.circle",
                            tint: AppColor.purple
                        )
                    }

                    if isBuiltin {
                        Button(action: resetToDefault) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 14, weight: .regular))
                                Text("元に戻す")
                                    .bikeyFont(14, weight: .medium, relativeTo: .body)
                            }
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white, in: Capsule())
                            .overlay(
                                Capsule().stroke(AppColor.rule.opacity(0.4), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let entry = payload.entry, let onDelete {
                        Button(role: .destructive) {
                            Task {
                                guard !isSaving else { return }
                                isSaving = true
                                validationMessage = await onDelete(entry)
                                isSaving = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .regular))
                                Text("削除")
                                    .bikeyFont(14, weight: .medium, relativeTo: .body)
                            }
                            .foregroundStyle(AppColor.purple)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white, in: Capsule())
                            .overlay(
                                Capsule().stroke(AppColor.rule.opacity(0.4), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColor.background.ignoresSafeArea())
        .bikeyKeyboardToolbar { focusedField = nil }
        .onAppear {
            if payload.isNewCustom {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    focusedField = .title
                }
            }
        }
    }

    private func resetToDefault() {
        Task {
            guard let defaults = await onReset(payload) else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                title = defaults.title
                prompt = defaults.prompt
            }
        }
    }
}

private struct EditorTopBar: View {
    let cancelAction: () -> Void
    let saveAction: () -> Void
    let isSaveEnabled: Bool
    let isSaving: Bool

    var body: some View {
        HStack {
            Button(action: cancelAction) {
                Text("キャンセル")
                    .bikeyFont(15, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: saveAction) {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(AppColor.ink)
                            .scaleEffect(0.8)
                    } else {
                        Text("保存")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(isSaveEnabled ? AppColor.ink : AppColor.softText)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(isSaveEnabled ? 0.05 : 0.02), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(!isSaveEnabled)
        }
    }
}

private struct EditorTitleField: View {
    @Binding var text: String
    var focused: FocusState<EditorField?>.Binding

    private var isFocused: Bool { focused.wrappedValue == .title }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タイトル")
                .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)

            HStack(alignment: .center, spacing: 8) {
                TextField("敬語", text: $text)
                    .focused(focused, equals: .title)
                    .bikeyFont(16, weight: .regular, relativeTo: .body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .foregroundStyle(AppColor.ink)
                    .onChange(of: text) { newValue in
                        if newValue.count > titleCharLimit {
                            text = String(newValue.prefix(titleCharLimit))
                        }
                    }
                    .onSubmit { focused.wrappedValue = .prompt }

                Text("\(text.count)/\(titleCharLimit)")
                    .bikeyFont(12, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.softText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused ? AppColor.ink.opacity(0.18) : AppColor.rule.opacity(0.25),
                        lineWidth: isFocused ? 1 : 0.6
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
            .contentShape(Rectangle())
            .onTapGesture { focused.wrappedValue = .title }
        }
    }
}

private struct EditorPromptField: View {
    @Binding var text: String
    var focused: FocusState<EditorField?>.Binding

    private var isFocused: Bool { focused.wrappedValue == .prompt }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("プロンプト")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                Spacer()
                Text("\(text.count)/\(promptCharLimit)")
                    .bikeyFont(12, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.softText)
                    .monospacedDigit()
            }

            TextEditor(text: $text)
                .focused(focused, equals: .prompt)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .scrollContentBackground(.hidden)
                .foregroundStyle(AppColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 160)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused ? AppColor.ink.opacity(0.18) : AppColor.rule.opacity(0.25),
                            lineWidth: isFocused ? 1 : 0.6
                        )
                )
                .animation(.easeInOut(duration: 0.18), value: isFocused)
                .onChange(of: text) { newValue in
                    if newValue.count > promptCharLimit {
                        text = String(newValue.prefix(promptCharLimit))
                    }
                }
        }
    }
}

// MARK: - Sheet helper

private extension View {
    func editorSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item) { value in
            content(value)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(AppColor.background)
        }
    }
}
