import Testing
import Foundation
@testable import AICore

struct OpenCodeHeadersTests {

    // MARK: - Scope

    @Test func onlyTheTwoOpenCodeProvidersGetHeaders() {
        for provider in AIProvider.allCases where provider != .opencodeZen && provider != .opencodeGo {
            #expect(OpenCodeHeaders.headers(for: provider).isEmpty, "\(provider.rawValue) should not be identified to opencode.ai")
        }
    }

    @Test(arguments: [AIProvider.opencodeZen, .opencodeGo])
    func openCodeProvidersSendTheFullHeaderSet(provider: AIProvider) {
        let sut = OpenCodeHeaders.headers(for: provider)

        #expect(Set(sut.keys) == [
            "x-opencode-client",
            "x-opencode-session",
            "x-opencode-request",
            "User-Agent"
        ])
    }

    // MARK: - Session affinity

    /// The whole point of the header: the gateway keys its prompt cache on it,
    /// so a fresh id per request would throw the cache away every time.
    @Test func sessionIDIsStableAcrossRequests() {
        let first = OpenCodeHeaders.headers(for: .opencodeGo)["x-opencode-session"]
        let second = OpenCodeHeaders.headers(for: .opencodeZen)["x-opencode-session"]

        #expect(first == second)
        #expect(first?.isEmpty == false)
    }

    @Test func requestIDIsUniquePerCall() {
        let first = OpenCodeHeaders.headers(for: .opencodeGo)["x-opencode-request"]
        let second = OpenCodeHeaders.headers(for: .opencodeGo)["x-opencode-request"]

        #expect(first != second)
    }

    // MARK: - Honest identification

    /// The official CLI sends `x-opencode-client: cli` under an `opencode/…`
    /// user agent. Claiming either would be passing this app off as that
    /// client to get its rate limits.
    @Test func doesNotImpersonateTheOfficialCLI() {
        let sut = OpenCodeHeaders.headers(for: .opencodeGo)

        #expect(sut["x-opencode-client"] == "vivadicta")
        #expect(sut["User-Agent"]?.hasPrefix("VivaDicta/") == true)
        #expect(sut["User-Agent"]?.localizedStandardContains("opencode") == false)
    }
}
