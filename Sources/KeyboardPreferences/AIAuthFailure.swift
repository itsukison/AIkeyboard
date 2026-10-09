public enum AIAuthFailure {
    public static func requiresSignIn(code: String) -> Bool {
        switch code {
        case "refresh_token_not_found", "refresh_token_already_used", "session_not_found",
             "session_expired", "user_not_found", "user_banned", "invalid_grant":
            return true
        default:
            return false
        }
    }
}
