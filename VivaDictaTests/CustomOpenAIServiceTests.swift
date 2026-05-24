// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import os
import Testing
@testable import VivaDicta

/// Tests cover `CustomOpenAIService` in isolation: the status-code mapping,
/// API-key forwarding, body shape, and URLError handling - both raw and
/// wrapped in `NetworkError.transport`.
@Suite("CustomOpenAIService")
struct CustomOpenAIServiceTests {

    private let endpointURL = "https://api.example.com/v1/chat/completions"

    private func makeHTTPResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: endpointURL)!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func makeSUT(networkService: MockNetworkService) -> CustomOpenAIService {
        CustomOpenAIService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "CustomOpenAIServiceTests")
        )
    }

    // MARK: - Success path

    @Test func testEndpointReturnsSuccessOn200() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: "sk-test")

        #expect(result == .success(message: "Connected successfully"))
        #expect(result.isSuccess)
    }

    // MARK: - Request shape

    @Test func testEndpointSendsBearerAuthorizationWhenAPIKeyProvided() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: "sk-abc")

        #expect(networkService.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-abc")
    }

    @Test func testEndpointOmitsAuthorizationWhenAPIKeyIsNil() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(networkService.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func testEndpointOmitsAuthorizationWhenAPIKeyIsEmpty() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: "")

        #expect(networkService.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func testEndpointSendsMinimalChatCompletionBody() async throws {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(200)))
        let sut = makeSUT(networkService: networkService)

        _ = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4-test", apiKey: nil)

        let body = try #require(networkService.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "gpt-4-test")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "test"]])
    }

    // MARK: - Status code mapping

    @Test func testEndpointMapsUnauthorizedTo401Message() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(401)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: "sk-test")

        #expect(result == .failure(message: "Authentication failed. Check your API key."))
    }

    @Test func testEndpointMapsNotFoundTo404Message() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(404)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Endpoint not found. Check the URL."))
    }

    @Test func testEndpointExtractsErrorMessageFromBadRequestBody() async {
        let networkService = MockNetworkService()
        let body = Data(#"{"error": {"message": "model 'foo' not found"}}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(400)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "foo", apiKey: nil)

        #expect(result == .failure(message: "model 'foo' not found"))
    }

    @Test func testEndpointFallsBackToGenericMessageOnMalformedBadRequestBody() async {
        let networkService = MockNetworkService()
        let body = Data("plain text error".utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(400)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        if case let .failure(message) = result {
            #expect(message.hasPrefix("Bad request: "))
        } else {
            Issue.record("Expected .failure, got \(result)")
        }
    }

    @Test func testEndpointMapsServerErrorTo5xxMessage() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(503)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Server error (503). Try again later."))
    }

    // MARK: - Transport errors

    @Test func testEndpointMapsCannotConnectToFriendlyMessage() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(NetworkError.transport(URLError(.cannotConnectToHost)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Cannot connect to server. Check the URL and that the server is running."))
    }

    @Test func testEndpointMapsTimeoutToFriendlyMessage() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(NetworkError.transport(URLError(.timedOut)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Connection timed out. Server may be slow or unreachable."))
    }

    @Test func testEndpointMapsNoInternetToFriendlyMessage() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(NetworkError.transport(URLError(.notConnectedToInternet)))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "No internet connection."))
    }

    /// Covers the production-reachable path where the typed
    /// `error as? URLError` cast succeeds (URLError thrown directly OR
    /// bridged from `NSError(domain: NSURLErrorDomain, ...)`). The
    /// `NetworkError.transport(URLError)` tests above exercise a fallback
    /// path that fires in the test bundle but not in production - see the
    /// "Two paths, two contexts" doc on `unwrapURLError`. This test pins
    /// the production code path so it doesn't silently break.
    @Test func testEndpointMapsRawURLErrorTransportToFriendlyMessage() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(URLError(.timedOut))
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Connection timed out. Server may be slow or unreachable."))
    }

    @Test func testEndpointMapsBridgedNSURLErrorDomainToFriendlyMessage() async {
        let networkService = MockNetworkService()
        // NSError(domain: NSURLErrorDomain, code: ...) bridges to URLError,
        // so the typed `error as? URLError` cast in `unwrapURLError` succeeds
        // for it - same as the production case where `DefaultNetworkService`
        // would have surfaced a `NetworkError.transport(URLError)`.
        let nsError = NSError(domain: NSURLErrorDomain, code: URLError.cannotConnectToHost.rawValue)
        networkService.stubSendResponse = .failure(nsError)
        let sut = makeSUT(networkService: networkService)

        let result = await sut.testEndpoint(endpointURL: endpointURL, modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Cannot connect to server. Check the URL and that the server is running."))
    }

    @Test func testEndpointReturnsInvalidURLFailureForUnparseableEndpoint() async {
        let networkService = MockNetworkService()
        let sut = makeSUT(networkService: networkService)

        // Empty string is the one URL(string:) actually rejects.
        let result = await sut.testEndpoint(endpointURL: "", modelName: "gpt-4", apiKey: nil)

        #expect(result == .failure(message: "Invalid endpoint URL format"))
        #expect(networkService.sendCallCount == 0)
    }
}
