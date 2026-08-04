import KeyboardPreferences

public enum AIKeyboardState: Equatable {
    case hidden
    case overflow
    /// `existing` grows as streamed candidates land; `pending` is how many are
    /// still expected, and drives the number of shimmer placeholders shown.
    case generating(prompt: UserPrompt, capture: WholeInputCapture, refinement: RefinementIntent?, existing: [RewriteCandidate], pending: Int)
    case result(prompt: UserPrompt, capture: WholeInputCapture, candidates: [RewriteCandidate], selectedIndex: Int)
    case error(prompt: UserPrompt?, message: String)
    case consentRequired(prompt: UserPrompt?)
    case fullAccessRequired(prompt: UserPrompt?)
}
