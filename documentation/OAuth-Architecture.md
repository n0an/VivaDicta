# OAuth Architecture

## Overview

VivaDicta supports OAuth sign-in for AI providers, allowing users to use their existing subscriptions (e.g., ChatGPT Plus/Pro) instead of separate API keys. The implementation uses PKCE (Proof Key for Code Exchange) OAuth 2.0 with a local callback server bridge pattern unique to iOS.

## Supported Providers

| Provider | Auth Flow | Status |
|----------|-----------|--------|
| ChatGPT (OpenAI) | PKCE OAuth + local server bridge | Implemented |
| Gemini (Google) | PKCE OAuth + local server bridge | Planned |
| GitHub Copilot | Device code flow (no server needed) | Planned |

## iOS Authentication Flow

### The Challenge

OAuth providers like OpenAI register specific redirect URIs for their client IDs. The Codex CLI client ID (`app_EMoamEEZ73f0CkXaXp7hrann`) only accepts `http://localhost:*` redirects. However, `ASWebAuthenticationSession` on iOS can only intercept custom URL schemes (like `vivadicta://`), not localhost URLs.

### The Solution: Local Server Bridge

A temporary `NWListener` TCP server bridges the gap between the provider's localhost redirect and the app's custom URL scheme.

```
┌─────────┐    ┌──────────────┐    ┌────────────┐    ┌───────────────┐
│  User    │───>│ ASWebAuth    │───>│  OpenAI    │───>│  localhost    │
│  taps    │    │ Session      │    │  auth.     │    │  :1455        │
│  Sign In │    │ (in-app      │    │  openai.   │    │  (NWListener) │
│          │    │  browser)    │    │  com       │    │               │
└─────────┘    └──────────────┘    └────────────┘    └───────┬───────┘
                      ▲                                       │
                      │                                       │
                      │  vivadicta://auth/callback?code=xxx   │
                      │◄──────────────────────────────────────┘
                      │         HTTP 302 redirect
                      │
               Session intercepts
               custom scheme, closes
               browser, returns URL
```

### Step-by-Step

1. **Start local server** — `OAuthCallbackServer` starts an `NWListener` on port 1455
2. **Open in-app browser** — `ASWebAuthenticationSession` opens the provider's auth URL
3. **User authenticates** — Logs in at the provider's website (e.g., auth.openai.com)
4. **Provider redirects to localhost** — `http://localhost:1455/auth/callback?code=xxx&state=yyy`
5. **Local server bridges** — Receives the request, responds with `302 → vivadicta://auth/callback?code=xxx&state=yyy`
6. **Session intercepts** — `ASWebAuthenticationSession` sees the `vivadicta://` scheme, closes the browser, returns the callback URL
7. **Server shuts down** — `defer { listener.cancel() }` stops the server immediately
8. **Token exchange** — App exchanges the authorization code for access/refresh tokens
9. **Credentials stored** — Tokens saved to Keychain (device-local, not synced)

The local server exists only for a few seconds during sign-in. All subsequent API calls and token refreshes use standard HTTP requests.

## File Structure

```
Services/OAuth/
├── OAuthManager.swift              — @MainActor singleton managing sign-in, token refresh, credential storage
├── OAuthProvider.swift             — Protocol for provider configurations
├── OAuthCredential.swift           — Token + account info model (Codable)
├── OAuthError.swift                — Error types
├── PKCEGenerator.swift             — PKCE code verifier/challenge generation
├── OAuthCallbackServer.swift       — NWListener localhost → custom scheme bridge
├── ASWebAuthSessionContextProvider.swift — Presentation context for ASWebAuthenticationSession
├── OpenAIChatGPTOAuthProvider.swift — OpenAI/ChatGPT provider configuration
└── ChatGPTAPIClient.swift          — ChatGPT backend API client (SSE streaming)
```

## Token Lifecycle

```
Sign-in → access_token + refresh_token stored in Keychain (syncable: false)
                │
                ▼
        On each API call:
        ┌─────────────────────┐
        │ isExpiringSoon?     │──No──> Use current token
        │ (< 5 min remaining)│
        └────────┬────────────┘
                 Yes
                  │
                  ▼
        Refresh token → new access_token
        (retry up to 3x with backoff)
                  │
                  ▼
        Save updated credential
```

- **Access tokens** — Short-lived (~1 hour), automatically refreshed
- **Refresh tokens** — Long-lived, used to obtain new access tokens
- **Storage** — Keychain with `syncable: false` (device-local, not iCloud synced)
- **Why not sync** — OAuth tokens are device-specific; syncing causes race conditions where one device's refresh invalidates the other's

## Request Routing & Fallback

When an AI request is made with OpenAI as the provider:

```
1. ChatGPT OAuth signed in?
   ├── Yes → Try ChatGPT backend API (chatgpt.com/backend-api/codex/responses)
   │         ├── Success → Return result
   │         └── OAuth error + API key exists → Fall through to step 2
   └── No → Step 2

2. API key exists?
   ├── Yes → Use standard OpenAI API (api.openai.com)
   └── No → Throw "not configured" error
```

## Model Lists

OAuth and API key access expose different model sets:

| Access Method | Models |
|--------------|--------|
| ChatGPT OAuth (Codex endpoint) | gpt-5.4, gpt-5.4-mini, gpt-5.2, gpt-5.1 |
| OpenAI API key | gpt-5.4, gpt-5.4-mini, gpt-5.4-nano, gpt-5.2, gpt-5.1, o4-mini, o3, o3-mini, gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, gpt-4o, gpt-4o-mini |

The model picker (`getAvailableModels(for:)`) automatically switches lists based on `isChatGPTSignedIn`. If a mode has a model selected that isn't in the OAuth list, `ChatGPTAPIClient.resolveModel()` falls back to `gpt-5.4-mini`.

## Adding a New OAuth Provider

1. Create a struct conforming to `OAuthProvider` (see `OpenAIChatGPTOAuthProvider` as template)
2. Set `redirectURI` to `http://localhost:<port>/auth/callback`
3. Create an API client enum if the provider uses a non-standard API
4. Add sign-in/sign-out/refresh methods to `AIService`
5. Update `refreshConnectedProviders()` and `isProperlyConfigured()`
6. Add UI in the provider's configuration view

For **device code flow** providers (like GitHub Copilot), no local server is needed — the flow uses polling instead of redirects.

## Comparison with macOS

| Aspect | macOS | iOS |
|--------|-------|-----|
| Redirect capture | `NWListener` TCP server on localhost | `NWListener` + 302 redirect to custom scheme |
| Browser | System browser via `NSWorkspace.shared.open()` | In-app browser via `ASWebAuthenticationSession` |
| Redirect URI | `http://localhost:1455/auth/callback` | `http://localhost:1455/auth/callback` (same) |
| OAuthManager | `actor` | `@MainActor final class` (Swift 6 strict concurrency) |
| Codex CLI import | Imports from `~/.codex/auth.json` | Not applicable |
