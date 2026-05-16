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
        let sut = MockURLSession()
        sut.stubUploadResponse = .success((Data("ok".utf8), makeResponse(200)))

        let request = URLRequest(url: URL(string: "https://example.com/x")!)
        let (data, response) = try await sut.upload(for: request, from: Data())

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test func propagatesStubbedError() async {
        struct Boom: Error {}
        let sut = MockURLSession()
        sut.stubUploadResponse = .failure(Boom())

        await #expect(throws: Boom.self) {
            _ = try await sut.upload(
                for: URLRequest(url: URL(string: "https://example.com")!),
                from: Data()
            )
        }
    }

    @Test func capturesRequestAndBody() async throws {
        let sut = MockURLSession()
        sut.stubUploadResponse = .success((Data(), makeResponse(200)))

        var request = URLRequest(url: URL(string: "https://example.com/api")!)
        request.httpMethod = "POST"
        request.setValue("Bearer xyz", forHTTPHeaderField: "Authorization")
        let body = Data("payload".utf8)

        _ = try await sut.upload(for: request, from: body)

        #expect(sut.uploadCallCount == 1)
        #expect(sut.capturedRequest?.url?.absoluteString == "https://example.com/api")
        #expect(sut.capturedRequest?.httpMethod == "POST")
        #expect(sut.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer xyz")
        #expect(sut.capturedBody == body)
    }

    @Test func unsetStubRecordsIssue() async {
        await withKnownIssue {
            let sut = MockURLSession()
            await #expect(throws: StubNotSetError.self) {
                _ = try await sut.upload(
                    for: URLRequest(url: URL(string: "https://example.com")!),
                    from: Data()
                )
            }
        }
    }

    @Test func didUploadCallbackFiresAfterCall() async throws {
        let sut = MockURLSession()
        sut.stubUploadResponse = .success((Data(), makeResponse(200)))

        var fired = false
        sut.didUpload = { fired = true }

        _ = try await sut.upload(
            for: URLRequest(url: URL(string: "https://example.com")!),
            from: Data()
        )
        #expect(fired)
    }
}
