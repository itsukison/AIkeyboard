import KeyboardPreferences

public enum AIKeyboardState: Equatable {
    case hidden
    case overflow
    case generating(prompt: UserPrompt, capture: WholeInputCapture, refinement: RefinementIntent?, existing: [RewriteCandidate])
    case result(prompt: UserPrompt, capture: WholeInputCapture, candidates: [RewriteCandidate], selectedIndex: Int)
    case error(prompt: UserPrompt?, message: String)
    case consentRequired(prompt: UserPrompt?)
    case fullAccessRequired(prompt: UserPrompt?)
}
