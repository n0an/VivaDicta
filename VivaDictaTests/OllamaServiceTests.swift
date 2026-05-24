// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import os
import Testing
@testable import VivaDicta

/// Tests cover `OllamaService` in isolation: the HTTP shape of model
/// fetching (OpenAI-compatible + native fallback) and connection checks.
/// `MockNetworkService` stands in for the real network.
@Suite("OllamaService")
struct OllamaServiceTests {

    private let serverURL = "http://localhost:11434"

    private func makeHTTPResponse(_ url: URL, code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    private func openAIEndpoint() -> URL { URL(string: "\(serverURL)/v1/models")! }
    private func nativeEndpoint() -> URL { URL(string: "\(serverURL)/api/tags")! }

    private func makeSUT(networkService: MockNetworkService) -> OllamaService {
        OllamaService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "OllamaServiceTests")
        )
    }

    // MARK: - fetchModels (OpenAI-compatible path)

    @Test func fetchModelsParsesOpenAICompatibleResponse() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"data": [{"id": "llama3.2"}, {"id": "qwen2.5"}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(openAIEndpoint(), code: 200)))
        let sut = makeSUT(networkService: networkService)

        let models = try await sut.fetchModels(serverURL: serverURL)

        #expect(models == ["llama3.2", "qwen2.5"])
        #expect(networkService.capturedRequest?.url == openAIEndpoint())
    }

    @Test func fetchModelsReturnsSortedNames() async throws {
        let networkService = MockNetworkService()
        let body = Data(#"{"data": [{"id": "zebra"}, {"id": "alpha"}, {"id": "mid"}]}"#.utf8)
        networkService.stubSendResponse = .success((body, makeHTTPResponse(openAIEndpoint(), code: 200)))
        let sut = makeSUT(networkService: networkService)

        let models = try await sut.fetchModels(serverURL: serverURL)

        #expect(models == ["alpha", "mid", "zebra"])
    }

    // MARK: - fetchModels (native fallback path)

    @Test func fetchModelsFallsBackToNativeWhenOpenAICompatibleFailsParse() async throws {
        // OpenAI-compatible returns 200 but malformed; native returns valid.
        let networkService = SequencedMockNetworkService(responses: [
            .success((Data(#"{"unexpected": []}"#.utf8), makeHTTPResponse(openAIEndpoint(), code: 200))),
            .success((Data(#"{"models": [{"name": "llama3.2"}]}"#.utf8), makeHTTPResponse(nativeEndpoint(), code: 200)))
        ])
        let sut = OllamaService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "OllamaServiceTests")
        )

        let models = try await sut.fetchModels(serverURL: serverURL)

        #expect(models == ["llama3.2"])
    }

    @Test func fetchModelsThrowsWhenBothEndpointsFail() async {
        let networkService = SequencedMockNetworkService(responses: [
            .success((Data(), makeHTTPResponse(openAIEndpoint(), code: 500))),
            .success((Data(), makeHTTPResponse(nativeEndpoint(), code: 500)))
        ])
        let sut = OllamaService(
            networkService: networkService,
            logger: Logger(subsystem: "test", category: "OllamaServiceTests")
        )

        await #expect(throws: OllamaServiceError.self) {
            _ = try await sut.fetchModels(serverURL: serverURL)
        }
    }

    // MARK: - checkConnection

    @Test func checkConnectionReturnsTrueOn200() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(nativeEndpoint(), code: 200)))
        let sut = makeSUT(networkService: networkService)

        let reachable = await sut.checkConnection(serverURL: serverURL)

        #expect(reachable)
        #expect(networkService.capturedRequest?.url == nativeEndpoint())
    }

    @Test func checkConnectionReturnsFalseOnNon200() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .success((Data(), makeHTTPResponse(nativeEndpoint(), code: 503)))
        let sut = makeSUT(networkService: networkService)

        let reachable = await sut.checkConnection(serverURL: serverURL)

        #expect(!reachable)
    }

    @Test func checkConnectionReturnsFalseOnTransportError() async {
        let networkService = MockNetworkService()
        networkService.stubSendResponse = .failure(URLError(.notConnectedToInternet))
        let sut = makeSUT(networkService: networkService)

        let reachable = await sut.checkConnection(serverURL: serverURL)

        #expect(!reachable)
    }

}

/// Local helper that returns a different stubbed response per call, so we
/// can exercise the OpenAI-compatible -> native fallback path in one test.
/// Lives only in this file - if a second test needs it, promote to
/// NetworkingMocks.
private final class SequencedMockNetworkService: NetworkService, @unchecked Sendable {
    private var responses: [Result<(Data, HTTPURLResponse), Error>]
    private(set) var capturedRequests: [URLRequest] = []

    init(responses: [Result<(Data, HTTPURLResponse), Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest, acceptableStatusCodes: Set<Int>?) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        guard !responses.isEmpty else { fatalError("SequencedMockNetworkService exhausted") }
        return try responses.removeFirst().get()
    }

    func sendJSON<T: Decodable>(_ request: URLRequest, as type: T.Type, decoder: JSONDecoder, acceptableStatusCodes: Set<Int>?) async throws -> T {
        fatalError("not used in these tests")
    }

    func upload(_ request: URLRequest, from bodyData: Data, acceptableStatusCodes: Set<Int>?) async throws -> (Data, HTTPURLResponse) {
        fatalError("not used in these tests")
    }

    func bytes(for request: URLRequest, acceptableStatusCodes: Set<Int>?) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        fatalError("not used in these tests")
    }
}
