// Copyright © 2026 Anton Novoselov. All rights reserved.

import Testing
@testable import TestUtilities

struct EvaluateTests {

    @Test func successReturnsValue() throws {
        let stub: Result<Int, Error>? = .success(42)
        let value: Int = try stub.evaluate()
        #expect(value == 42)
    }

    @Test func failureThrowsError() {
        struct Boom: Error, Equatable {}
        let stub: Result<Int, Error>? = .failure(Boom())

        #expect(throws: Boom.self) {
            let _: Int = try stub.evaluate()
        }
    }

    @Test(.disabled("Records an Issue by design; enable to verify behavior manually"))
    func nilStubRecordsIssueAndThrows() {
        let stub: Result<Int, Error>? = nil
        #expect(throws: StubNotSetError.self) {
            let _: Int = try stub.evaluate()
        }
    }
}
