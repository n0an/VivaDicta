// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import NetworkingMocks
import Testing

@Suite("DefaultNetworkService")
struct DefaultNetworkServiceTests {

    private let endpoint = URL(string: "https://example.com/api")!

    private func makeResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: endpoint,
            statusCode: code,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    // MARK: send

    @Test func sendReturnsBodyAndHTTPResponseOnSuccess() async throws {
        let session = MockURLSession()
        let payload = Data(#"{"ok":true}"#.utf8)
        session.stubDataResponse = .success((payload, makeResponse(200)))
        let client = DefaultNetworkService(session: session)

        let (data, response) = try await client.send(URLRequest(url: endpoint))

        #expect(data == payload)
        #expect(response.statusCode == 200)
        #expect(session.dataCallCount == 1)
    }

    @Test func sendThrowsUnacceptableStatusFor4xx() async throws {
        let session = MockURLSession()
        let body = Data(#"{"error":"nope"}"#.utf8)
        session.stubDataResponse = .success((body, makeResponse(404)))
        let client = DefaultNetworkService(session: session)

        await #expect {
            try await client.send(URLRequest(url: endpoint))
        } throws: { error in
            guard let net = error as? NetworkError,
                  case let .unacceptableStatus(code, payload) = net else {
                return false
            }
            return code == 404 && payload == body
        }
    }

    @Test func sendWrapsTransportError() async throws {
        struct Boom: Error {}
        let session = MockURLSession()
        session.stubDataResponse = .failure(Boom())
        let client = DefaultNetworkService(session: session)

        await #expect {
            try await client.send(URLRequest(url: endpoint))
        } throws: { error in
            guard let net = error as? NetworkError,
                  case .transport = net else { return false }
            return true
        }
    }

    @Test func customAcceptableStatusCodesOverrideDefault() async throws {
        let session = MockURLSession()
        session.stubDataResponse = .success((Data(), makeResponse(302)))
        let client = DefaultNetworkService(session: session)

        let (_, response) = try await client.send(
            URLRequest(url: endpoint),
            acceptableStatusCodes: [200, 302]
        )
        #expect(response.statusCode == 302)
    }

    // MARK: sendJSON

    private struct Echo: Decodable, Equatable {
        let value: String
    }

    @Test func sendJSONDecodesResponse() async throws {
        let session = MockURLSession()
        session.stubDataResponse = .success((Data(#"{"value":"hi"}"#.utf8), makeResponse(200)))
        let client = DefaultNetworkService(session: session)

        let result: Echo = try await client.sendJSON(URLRequest(url: endpoint))

        #expect(result == Echo(value: "hi"))
    }

    @Test func sendJSONWrapsDecodingErrors() async throws {
        let session = MockURLSession()
        session.stubDataResponse = .success((Data(#"{"wrong":"shape"}"#.utf8), makeResponse(200)))
        let client = DefaultNetworkService(session: session)

        await #expect {
            let _: Echo = try await client.sendJSON(URLRequest(url: endpoint))
        } throws: { error in
            guard let net = error as? NetworkError,
                  case .decodingFailed = net else { return false }
            return true
        }
    }

    // MARK: upload

    @Test func uploadPassesBodyToSession() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data(), makeResponse(200)))
        let client = DefaultNetworkService(session: session)

        let body = Data("payload".utf8)
        _ = try await client.upload(URLRequest(url: endpoint), from: body)

        #expect(session.uploadCallCount == 1)
        #expect(session.capturedBody == body)
    }

    @Test func uploadThrowsForServerErrors() async throws {
        let session = MockURLSession()
        session.stubUploadResponse = .success((Data("internal".utf8), makeResponse(500)))
        let client = DefaultNetworkService(session: session)

        await #expect {
            _ = try await client.upload(URLRequest(url: endpoint), from: Data())
        } throws: { error in
            (error as? NetworkError)?.statusCode == 500
        }
    }

    // MARK: NetworkError accessors

    @Test func statusAccessorsExposeBodyAndCode() {
        let error = NetworkError.unacceptableStatus(code: 418, body: Data("teapot".utf8))
        #expect(error.statusCode == 418)
        #expect(error.bodyString == "teapot")
    }

    @Test func statusAccessorsReturnDefaultsForOtherCases() {
        #expect(NetworkError.invalidResponse.statusCode == nil)
        #expect(NetworkError.invalidResponse.bodyString == "")
    }
}
