import KeyboardPreferences
import SwiftUI

/// Turns the builder's answers into a button and writes it to the prompt cache.
///
/// The chip combinations are fixed and finite, so the button is assembled from
/// authored fragments (`PresetPromptTemplate`) with no network call at all. The
/// model is reached only when the user typed a free-text note or chose その他,
/// which a fixed template cannot fully cover. Generation failure is never fatal: it
/// falls back to the templated button silently, because a slightly less tailored
/// button beats blocking a first session on a network call.
enum OnboardingButtonBuilderService {
    /// One completed builder pass: the button, plus the offline worked example
    /// the practice page replays if this button ends up being the main one.
    struct Built {
        let spec: OnboardingButtonSpec
        let practice: OnboardingGeneratedPractice?
        let useCase: OnboardingUseCase
        /// `template` or `generated`. Reported at commit time, not at build
        /// time: the templated button is always built first so it can serve as
        /// the fallback, and counting it there would report two creations for
        /// every note the model successfully answered.
        let source: String
    }

    // MARK: - Building

    /// The chip-driven path: no network, no wait. `nil` only for `.custom`,
    /// which has no chip selections and therefore no template.
    static func templated(
        useCase: OnboardingUseCase,
        spec: ButtonBuilderSpec,
        selections: BuilderSelections
    ) -> Built? {
        guard selections.chip("language")?.id != "other" else { return nil }
        guard let template = OnboardingButtonBuilder.template(for: useCase) else { return nil }
        return Built(
            spec: OnboardingButtonSpec(
                title: spec.autoName(selections),
                prompt: template.prompt(for: selections),
                builtinKey: nil,
                origin: .onboardingBuilder
            ),
            practice: template.practiceExample(for: selections),
            useCase: useCase,
            source: "template"
        )
    }

    /// The free-text path from the use-case page. `.custom` has no chip
    /// selections and therefore no template, so a failure here has nothing to
    /// fall back to and surfaces as an error.
    static func buildFromDescription(
        _ description: String,
        useCase: OnboardingUseCase
    ) async -> OnboardingCustomPresetService.Result? {
        do {
            let result = try await OnboardingCustomPresetService.generate(
                description: description,
                useCase: useCase.rawValue
            )
            return result
        } catch {
            AppAnalytics.capture("onboarding_button_generation_failed", properties: [
                "use_case": useCase.rawValue,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
            return nil
        }
    }

    /// The typed-input path. Called only when the user entered something a
    /// template cannot express; the caller falls back to the template on `nil`.
    static func generated(
        description: String,
        useCase: OnboardingUseCase,
        name: String
    ) async -> Built? {
        do {
            let result = try await OnboardingCustomPresetService.generate(
                description: description,
                useCase: useCase.rawValue
            )
            guard let main = result.specs.first else { return nil }
            // The user's name wins over the model's: they chose the chips it was
            // derived from, and the toolbar budget is ours to enforce.
            let clamped = OnboardingButtonName.clamp(name)
            return Built(
                spec: OnboardingButtonSpec(
                    title: clamped.isEmpty ? main.title : clamped,
                    prompt: main.prompt,
                    builtinKey: main.builtinKey,
                    origin: .onboardingBuilder
                ),
                practice: result.practice,
                useCase: useCase,
                source: "generated"
            )
        } catch {
            AppAnalytics.capture("onboarding_button_generation_failed", properties: [
                "use_case": useCase.rawValue,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
            return nil
        }
    }

    /// Fired from `commit`, or directly by the control arm, which writes its
    /// preset set without going through the builder's commit path.
    static func capture(
        useCase: OnboardingUseCase,
        source: String,
        buttonIndex: Int
    ) {
        AppAnalytics.capture("onboarding_button_created", properties: [
            "use_case": useCase.rawValue,
            "source": source,
            "button_index": buttonIndex,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
    }

    // MARK: - Committing

    /// Writes the built button, replacing the one from an earlier pass through
    /// the same pages when `replacing` is set — otherwise stepping back from the
    /// review page and pressing the CTA again would add a duplicate.
    ///
    /// The set that survives onboarding is **only** what the user built. The
    /// seeded 自然に / メール / 英訳 are dropped: they are the presets whose
    /// retention lift is a fraction of an authored button's, and leaving them in
    /// the toolbar makes the one button the user actually made harder to find.
    /// Anyone who wants more builds another, or adds them later in the Prompts
    /// screen.
    @discardableResult
    static func commit(_ built: Built, replacing existingId: UUID?) -> UUID {
        var entries = OnboardingPromptSetup.load().filter { $0.origin == .onboardingBuilder }

        let id: UUID
        if let existingId, let index = entries.firstIndex(where: { $0.id == existingId }) {
            id = existingId
            var replaced = entries[index]
            replaced.title = built.spec.title
            replaced.prompt = built.spec.prompt
            replaced.updatedAt = Date()
            entries[index] = replaced
        } else {
            let addition = UserPrompt(
                slot: entries.isEmpty ? .main : .sub,
                builtinKey: built.spec.builtinKey,
                title: built.spec.title,
                prompt: built.spec.prompt,
                isEnabled: true,
                sortOrder: entries.count,
                origin: .onboardingBuilder
            )
            id = addition.id
            entries.append(addition)
        }

        OnboardingPromptSetup.save(entries)

        if existingId == nil {
            capture(
                useCase: built.useCase,
                source: built.source,
                buttonIndex: entries.count - 1
            )
        }

        // One example is stored, and it belongs to the main button — that is the
        // only one the practice page demonstrates. A second button leaves the
        // first one's example alone.
        if entries.first?.id == id {
            if let practice = built.practice {
                KeyboardSettingsStore.writeOnboardingGeneratedPractice(
                    OnboardingGeneratedPractice(
                        buttonId: id.uuidString,
                        input: practice.input,
                        outputs: practice.outputs
                    )
                )
            } else {
                KeyboardSettingsStore.clearOnboardingGeneratedPractice()
            }
        }

        return id
    }
}
