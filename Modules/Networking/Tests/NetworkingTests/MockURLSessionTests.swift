// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing
import TestUtilities

@Suite("MockURLSession contract")
struct MockURLSessionTests {

    private func makeResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    @Test func returnsStubbedSuccessResponse() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data("ok".utf8), makeResponse(200)))

        let request = URLRequest(url: URL(string: "https://example.com/x")!)
        let (data, response) = try await session.upload(for: request, from: Data())

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test func propagatesStubbedError() async {
        struct Boom: Error {}
        let session = MockURLSession()
        session.stubUploadResponse = .failure(Boom())

        await #expect(throws: Boom.self) {
            _ = try await session.upload(
                for: URLRequest(url: URL(string: "https://example.com")!),
                from: Data()
            )
        }
    }

    @Test func capturesRequestAndBody() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data(), makeResponse(200)))

        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.setValue("Bearer xyz", forHTTPHeaderField: "Authorization")
        let body = Data("payload".utf8)

        _ = try await session.upload(for: request, from: body)

        #expect(session.uploadCallCount == 1)
        #expect(session.capturedRequest?.url?.absoluteString == "https://example.com/api")
        #expect(session.capturedRequest?.httpMethod == "POST")
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer xyz")
        #expect(session.capturedBody == body)
    }

    @Test func unsetStubRecordsIssue() async {
        await withKnownIssue {
            let session = MockURLSession()
            await #expect(throws: StubNotSetError.self) {
                _ = try await session.upload(
                    for: URLRequest(url: URL(string: "https://example.com")!),
                    from: Data()
                )
            }
        }
    }

    @Test func didUploadCallbackFiresAfterCall() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data(), makeResponse(200)))

        var fired = false
        session.didUpload = { fired = true }

        _ = try await session.upload(
            for: URLRequest(url: URL(string: "https://example.com")!),
            from: Data()
        )
        #expect(fired)
    }
}
