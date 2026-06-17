import Foundation

/// Errors that can occur during AI text enhancement.
public enum EnhancementError: LocalizedError, Sendable {
    case notConfigured
    case invalidResponse
    case enhancementFailed
    case networkError
    case serverError
    case rateLimitExceeded
    case customError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider not configured"
        case .invalidResponse:
            return "Invalid response from AI"
        case .enhancementFailed:
            return "AI processing failed"
        case .networkError:
            return "Network connection failed"
        case .serverError:
            return "Server error occurred"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .customError(let message):
            return message
        }
    }

    public var failureReason: String {
        switch self {
        case .notConfigured:
            return "No AI provider API key is configured. Go to Settings and add your API key for the selected AI provider."
        case .invalidResponse:
            return "The AI provider returned an unexpected response format. Please try again or contact support if the issue persists."
        case .enhancementFailed:
            return "The AI service could not process the transcription. The text may be too short or contain unsupported content."
        case .networkError:
            return "Unable to connect to the AI service. Please check your internet connection and try again."
        case .serverError:
            return "The AI provider's server is temporarily unavailable. Please wait a few minutes and try again."
        case .rateLimitExceeded:
            return "You've exceeded the rate limit for the AI service. Please wait a moment before trying again, or upgrade your API plan."
        case .customError(let message):
            return "An error occurred: \(message)"
        }
    }
}
