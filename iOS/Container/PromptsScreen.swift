import KeyboardPreferences
import SwiftUI
import UIKit

private func orderedForDisplay(_ raw: [UserPrompt]) -> [UserPrompt] {
    let mains = raw.filter { $0.slot == .main }.sorted { $0.sortOrder < $1.sortOrder }
    let subs = raw.filter { $0.slot == .sub }.sorted { $0.sortOrder < $1.sortOrder }
    return mains + subs
}

/// List position is the source of truth: the top row is the main button
/// (must stay enabled), everything below is a sub button in toolbar order.
private func normalizedOrdering(_ ordered: [UserPrompt]) -> [UserPrompt] {
    var result = ordered
    for index in result.indices {
        result[index].slot = index == 0 ? .main : .sub
        result[index].sortOrder = max(0, index - 1)
        if index == 0 { result[index].isEnabled = true }
    }
    return result
}

struct PromptsScreen: View {
    @EnvironmentObject private var session: UserSession
    @State private var entries: [UserPrompt] = orderedForDisplay(UserPromptStore.readEntries())
    @State private var editorPayload: PromptEditorPayload?
    @State private var isSyncing = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var showAuth = false
    @State private var showResetConfirm = false
    @State private var orderingPushTask: Task<Void, Never>?

    private var isGuest: Bool { session.profile == nil }

    private func openEditor(_ entry: UserPrompt) {
        if isGuest {
            showAuth = true
        } else {
            editorPayload = .existing(entry)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColor.background.ignoresSafeArea()

                List {
                    Section {
                        PromptsHeader()

                        if isGuest {
                            GuestPromptsCTA { showAuth = true }
                                .padding(.top, BikeyMetrics.Spacing.s)
                        }

                        if let errorMessage {
                            PromptsNotice(
                                text: errorMessage,
                                systemName: "exclamationmark.circle",
                                tint: AppColor.purple
                            )
                            .padding(.top, BikeyMetrics.Spacing.s)
                        }

                        Text("上から順にキーボードのボタンになります。一番上がメインボタンです。長押しして並び替えできます。")
                            .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .padding(.top, BikeyMetrics.Spacing.s)
                            .background(ReorderLiftTuner())
                    }
                    .listRowInsets(plainRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    Section {
                        ForEach(entries) { entry in
                            promptCard(entry)
                        }
                        .onMove(perform: moveEntries)
                    }

                    Section {
                        if !isGuest {
                            resetAllButton
                        }

                        Color.clear
                            .frame(height: BikeyMetrics.Sizing.tabBarHeight + 40)
                    }
                    .listRowInsets(plainRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)

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
                    onDelete: payload.entry != nil && entries.count > 1 ? { entry in
                        await deletePrompt(entry: entry)
                    } : nil
                )
            }
            .task {
                await refreshEntries()
            }
            .onChange(of: session.profile) { _ in
                entries = orderedForDisplay(UserPromptStore.readEntries())
            }
            .confirmationDialog(
                "すべてのボタンを最初の状態に戻しますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("最初の4つに戻す", role: .destructive) {
                    Task { await resetAllPrompts() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("カスタムプロンプトは削除され、初期の4つのボタン（敬語・自然に・メール・英訳）に戻ります。")
            }
            .guestAuthCover(isPresented: $showAuth)
        }
    }

    // The inset-grouped layout already provides a ~20pt screen margin;
    // +4 lines these rows up with screenHorizontalInset (24).
    private var plainRowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
    }

    @ViewBuilder
    private func promptCard(_ entry: UserPrompt) -> some View {
        PromptRow(entry: entry, isMain: entry.id == entries.first?.id) {
            openEditor(entry)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(AppColor.surface)
        .listRowSeparatorTint(AppColor.rule.opacity(0.35))
        .moveDisabled(isGuest)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {}
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isGuest, entries.count > 1 {
                Button(role: .destructive) {
                    Task { _ = await deletePrompt(entry: entry) }
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
    }

    private var resetAllButton: some View {
        Button { showResetConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .regular))
                Text("最初の4つのボタンに戻す")
                    .bikeyFont(14, weight: .medium, relativeTo: .body)
            }
            .foregroundStyle(AppColor.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppColor.surface, in: Capsule())
            .overlay(
                Capsule().stroke(AppColor.rule.opacity(0.4), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        guard !isGuest else { return }
        var reordered = entries
        reordered.move(fromOffsets: source, toOffset: destination)
        applyOrdering(normalizedOrdering(reordered))
        AppAnalytics.capture("prompt_reordered")
    }

    private func applyOrdering(_ ordered: [UserPrompt]) {
        entries = ordered
        UserPromptStore.writeEntries(ordered)
        guard let profile = session.profile else { return }
        orderingPushTask?.cancel()
        orderingPushTask = Task {
            do {
                try await UserPromptRemoteStore.updateOrdering(ordered, userId: profile.id)
                if !Task.isCancelled { errorMessage = nil }
            } catch {
                if !Task.isCancelled { errorMessage = "並び替えを保存できませんでした。" }
            }
        }
    }

    private func nextSortOrder() -> Int {
        (entries.filter { $0.slot == .sub }.map(\.sortOrder).max() ?? -1) + 1
    }

    private func refreshEntries() async {
        entries = orderedForDisplay(UserPromptStore.readEntries())
        guard session.profile != nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await session.refreshUserPromptsCache()
            entries = orderedForDisplay(UserPromptStore.readEntries())
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
    ) async -> LocalizedStringKey? {
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
                AppAnalytics.capture("prompt_updated", properties: [
                    "is_builtin": entry.builtinKey != nil,
                ])
            } else {
                _ = try await UserPromptRemoteStore.insertCustomSubPrompt(
                    title: trimmedTitle,
                    prompt: trimmedPrompt,
                    sortOrder: nextSortOrder(),
                    userId: profile.id
                )
                AppAnalytics.capture("prompt_created")
            }
            try await session.refreshUserPromptsCache()
            entries = orderedForDisplay(UserPromptStore.readEntries())
            editorPayload = nil
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return nil
        } catch {
            let message: LocalizedStringKey = "保存できませんでした。"
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

    private func deletePrompt(entry: UserPrompt) async -> LocalizedStringKey? {
        guard let profile = session.profile else { return "サインインが必要です。" }
        isSyncing = true
        defer { isSyncing = false }
        let remaining = normalizedOrdering(entries.filter { $0.id != entry.id })
        withAnimation(.easeOut(duration: 0.22)) {
            entries = remaining
        }
        do {
            try await UserPromptRemoteStore.deletePrompt(id: entry.id, userId: profile.id)
            try await UserPromptRemoteStore.updateOrdering(remaining, userId: profile.id)
            AppAnalytics.capture("prompt_deleted")
            try await session.refreshUserPromptsCache()
            entries = orderedForDisplay(UserPromptStore.readEntries())
            editorPayload = nil
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return nil
        } catch {
            try? await session.refreshUserPromptsCache()
            entries = orderedForDisplay(UserPromptStore.readEntries())
            let message: LocalizedStringKey = "削除できませんでした。"
            errorMessage = message
            return message
        }
    }

    private func resetAllPrompts() async {
        guard let profile = session.profile else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await UserPromptRemoteStore.resetToDefaults(userId: profile.id)
            AppAnalytics.capture("prompts_reset_to_defaults")
            try await session.refreshUserPromptsCache()
            withAnimation(.easeOut(duration: 0.22)) {
                entries = orderedForDisplay(UserPromptStore.readEntries())
            }
            errorMessage = nil
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            errorMessage = "リセットできませんでした。"
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
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    let isMain: Bool
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
                        if isMain {
                            Text("メイン")
                                .bikeyFont(11, weight: .medium, relativeTo: .caption)
                                .foregroundStyle(AppColor.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColor.purple.opacity(0.1), in: Capsule())
                        }
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
    let text: LocalizedStringKey
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
    let onSave: (String, String, Bool) async -> LocalizedStringKey?
    let onReset: (PromptEditorPayload) async -> (title: String, prompt: String)?
    let onDelete: ((UserPrompt) async -> LocalizedStringKey?)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var prompt: String
    @State private var isEnabled: Bool
    @State private var isSaving = false
    @State private var validationMessage: LocalizedStringKey?
    @FocusState private var focusedField: EditorField?

    init(
        payload: PromptEditorPayload,
        onSave: @escaping (String, String, Bool) async -> LocalizedStringKey?,
        onReset: @escaping (PromptEditorPayload) async -> (title: String, prompt: String)?,
        onDelete: ((UserPrompt) async -> LocalizedStringKey?)?
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

    private var screenTitle: Text {
        if payload.isNewCustom { return Text("カスタムプロンプト") }
        if let title = payload.entry?.title { return Text(verbatim: title) }
        return Text("プロンプト")
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
                    screenTitle
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
                            .background(AppColor.surface, in: Capsule())
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
                            .background(AppColor.surface, in: Capsule())
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
                    .background(AppColor.surface, in: Capsule())
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
                .background(AppColor.surface, in: Capsule())
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

                Text(verbatim: "\(text.count)/\(titleCharLimit)")
                    .bikeyFont(12, weight: .regular, relativeTo: .caption)
                    .foregroundStyle(AppColor.softText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Text(verbatim: "\(text.count)/\(promptCharLimit)")
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
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

// MARK: - Reorder lift tuning

/// SwiftUI's List gives no control over the reorder lift: the long-press
/// delay is ~0.5s and the lifted cell is snapshotted with square corners.
/// This reaches into the backing UICollectionView to shorten the lift delay
/// and round the drag/drop previews. Only public API is touched, and every
/// hook is conditional — if a future iOS changes the hierarchy, the list
/// silently falls back to stock behavior.
struct ReorderLiftTuner: UIViewRepresentable {
    func makeUIView(context: Context) -> TunerView { TunerView() }
    func updateUIView(_ uiView: TunerView, context: Context) { uiView.scheduleTune() }

    final class TunerView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleTune()
        }

        func scheduleTune() {
            DispatchQueue.main.async { [weak self] in self?.tune() }
        }

        private func tune() {
            guard let collectionView = enclosingCollectionView() else { return }

            for case let longPress as UILongPressGestureRecognizer in collectionView.gestureRecognizers ?? [] {
                if longPress.minimumPressDuration > 0.2 {
                    longPress.minimumPressDuration = 0.2
                }
            }

            let proxies: ReorderProxyPair
            if let existing = ReorderProxyPair.store.object(forKey: collectionView) {
                proxies = existing
            } else {
                guard
                    let drag = collectionView.dragDelegate,
                    let drop = collectionView.dropDelegate,
                    let delegate = collectionView.delegate
                else { return }
                proxies = ReorderProxyPair(
                    drag: DragDelegateProxy(wrapping: drag),
                    drop: DropDelegateProxy(wrapping: drop),
                    list: ListDelegateProxy(wrapping: delegate)
                )
                ReorderProxyPair.store.setObject(proxies, forKey: collectionView)
            }
            if collectionView.dragDelegate !== proxies.drag {
                collectionView.dragDelegate = proxies.drag
            }
            if collectionView.dropDelegate !== proxies.drop {
                collectionView.dropDelegate = proxies.drop
            }
            if collectionView.delegate !== proxies.list {
                collectionView.delegate = proxies.list
            }

            for indexPath in collectionView.indexPathsForVisibleItems {
                if let cell = collectionView.cellForItem(at: indexPath) {
                    ListDelegateProxy.applyStaticSurface(to: cell, at: indexPath)
                }
            }
        }

        private func enclosingCollectionView() -> UICollectionView? {
            var view = superview
            while let current = view {
                if let collectionView = current as? UICollectionView { return collectionView }
                view = current.superview
            }
            return nil
        }
    }
}

/// Retained per collection view (weak key), so the proxies outlive the
/// tuner's own cell — the collection view only holds its delegates weakly.
private final class ReorderProxyPair: NSObject {
    @MainActor static let store = NSMapTable<UICollectionView, ReorderProxyPair>.weakToStrongObjects()

    let drag: DragDelegateProxy
    let drop: DropDelegateProxy
    let list: ListDelegateProxy

    init(drag: DragDelegateProxy, drop: DropDelegateProxy, list: ListDelegateProxy) {
        self.drag = drag
        self.drop = drop
        self.list = list
    }
}

/// Wraps SwiftUI's collection view delegate to give prompt-row cells a static
/// surface-colored background. SwiftUI's listRowBackground slides together with
/// the row content during swipe, so when the close animation overshoots to the
/// right the canvas color would flash in the gap on the left; the static layer
/// underneath makes that overshoot invisible.
private final class ListDelegateProxy: NSObject, UICollectionViewDelegate {
    /// Section 1 of the List is the prompt rows (0 = header, 2 = footer).
    private static let promptsSectionIndex = 1

    private let original: any UICollectionViewDelegate

    init(wrapping original: any UICollectionViewDelegate) {
        self.original = original
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original.responds(to: aSelector) ? original : super.forwardingTarget(for: aSelector)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        original.collectionView?(collectionView, willDisplay: cell, forItemAt: indexPath)
        Self.applyStaticSurface(to: cell, at: indexPath)
    }

    static func applyStaticSurface(to cell: UICollectionViewCell, at indexPath: IndexPath) {
        guard indexPath.section == promptsSectionIndex else { return }
        var configuration = UIBackgroundConfiguration.listGroupedCell()
        configuration.backgroundColor = UIColor(AppColor.surface)
        cell.backgroundConfiguration = configuration
    }
}

private func roundedPreviewParameters(
    _ parameters: UIDragPreviewParameters?,
    collectionView: UICollectionView,
    indexPath: IndexPath
) -> UIDragPreviewParameters? {
    let result = parameters ?? UIDragPreviewParameters()
    if let cell = collectionView.cellForItem(at: indexPath) {
        result.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 12)
    }
    result.backgroundColor = .clear
    return result
}

private final class DragDelegateProxy: NSObject, UICollectionViewDragDelegate {
    private let original: any UICollectionViewDragDelegate

    init(wrapping original: any UICollectionViewDragDelegate) {
        self.original = original
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original.responds(to: aSelector) ? original : super.forwardingTarget(for: aSelector)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        original.collectionView(collectionView, itemsForBeginning: session, at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dragPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        roundedPreviewParameters(
            original.collectionView?(collectionView, dragPreviewParametersForItemAt: indexPath),
            collectionView: collectionView,
            indexPath: indexPath
        )
    }
}

private final class DropDelegateProxy: NSObject, UICollectionViewDropDelegate {
    private let original: any UICollectionViewDropDelegate

    init(wrapping original: any UICollectionViewDropDelegate) {
        self.original = original
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original.responds(to: aSelector) ? original : super.forwardingTarget(for: aSelector)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        original.collectionView(collectionView, performDropWith: coordinator)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        roundedPreviewParameters(
            original.collectionView?(collectionView, dropPreviewParametersForItemAt: indexPath),
            collectionView: collectionView,
            indexPath: indexPath
        )
    }
}
