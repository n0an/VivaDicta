// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
import TestUtilities

@Suite("MockNetworkService contract")
struct MockNetworkServiceTests {

    private let endpoint = URL(string: "https://example.com/api")!

    private func makeResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: endpoint,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    @Test func sendReturnsStubbedResponse() async throws {
        let sut = MockNetworkService()
        let body = Data("ok".utf8)
        sut.stubSendResponse = .success((body, makeResponse(200)))

        let (data, response) = try await sut.send(URLRequest(url: endpoint))

        #expect(data == body)
        #expect(response.statusCode == 200)
        #expect(sut.sendCallCount == 1)
    }

    @Test func sendCapturesRequestAndStatusCodeOverride() async throws {
        let sut = MockNetworkService()
        sut.stubSendResponse = .success((Data(), makeResponse(200)))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer xyz", forHTTPHeaderField: "Authorization")
        _ = try await sut.send(request, acceptableStatusCodes: [200, 302])

        #expect(sut.capturedRequest?.url == endpoint)
        #expect(sut.capturedRequest?.httpMethod == "POST")
        #expect(sut.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer xyz")
        #expect(sut.capturedAcceptableStatusCodes == [200, 302])
    }

    @Test func sendPropagatesStubbedError() async {
        struct Boom: Error {}
        let sut = MockNetworkService()
        sut.stubSendResponse = .failure(Boom())

        await #expect(throws: Boom.self) {
            _ = try await sut.send(URLRequest(url: endpoint))
        }
    }

    private struct Echo: Decodable, Equatable {
        let value: String
    }

    @Test func sendJSONReturnsTypedStub() async throws {
        let sut = MockNetworkService()
        sut.stubSendJSONResponse = .success(Echo(value: "hi"))

        let result: Echo = try await sut.sendJSON(URLRequest(url: endpoint))

        #expect(result == Echo(value: "hi"))
        #expect(sut.sendJSONCallCount == 1)
    }

    @Test func sendJSONWithMismatchedStubThrowsStubNotSetError() async {
        let sut = MockNetworkService()
        sut.stubSendJSONResponse = .success("string instead of Echo")

        await #expect(throws: StubNotSetError.self) {
            let _: Echo = try await sut.sendJSON(URLRequest(url: endpoint))
        }
    }

    @Test func uploadCapturesBody() async throws {
        let sut = MockNetworkService()
        sut.stubUploadResponse = .success((Data(), makeResponse(200)))

        let body = Data("payload".utf8)
        _ = try await sut.upload(URLRequest(url: endpoint), from: body)

        #expect(sut.uploadCallCount == 1)
        #expect(sut.capturedBody == body)
    }

    @Test func unsetSendStubRecordsIssue() async {
        await withKnownIssue {
            let sut = MockNetworkService()
            await #expect(throws: StubNotSetError.self) {
                _ = try await sut.send(URLRequest(url: endpoint))
            }
        }
    }

    @Test func bytesAlwaysThrowsStubNotSetError() async {
        let sut = MockNetworkService()

        await #expect(throws: StubNotSetError.self) {
            _ = try await sut.bytes(for: URLRequest(url: endpoint))
        }
        #expect(sut.bytesCallCount == 1)
    }
}
