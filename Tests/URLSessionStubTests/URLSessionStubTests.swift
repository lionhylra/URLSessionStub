import XCTest
@testable import URLSessionStub

final class URLSessionStubTests: XCTestCase {

    var stub = URLSessionStub.shared

    override func setUp() async throws {
        stub.start()
    }

    override func tearDown() async throws {
        stub.removeAllRules()
        stub.stop()
    }

    func testMatch_regex() async throws {
        XCTAssertNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/hello")!)))

        stub.addRule(exactURL: "https://example.com/hello", response: .success(data: Data()))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/hello")!)))
        
        stub.removeAllRules()
        stub.addRule(exactURL: "abc://example.com/hello", response: .success(data: Data()))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "abc://example.com/hello")!)))
        
        stub.removeAllRules()
        stub.addRule(regex: /https:\/\/example.com.+/, response: .success(data: Data()))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/hello")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/world")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/path%20")!)))

        stub.removeAllRules()
        stub.addRule(regex: /.+example.com.+/, response: .success(data: Data()))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/hello")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/world")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/path%20")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "https://example.com/path%20?abcd=efg")!)))
    }

    func testMatch_customRule() async throws {
        XCTAssertNil(stub.match(urlRequest: URLRequest(url: URL(string: "abcd://abcd.com/abcd")!)))
        stub.addCustomRule { request in
            URLSessionStub.MockResponse.success(data: Data())
        }
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "abcd://abcd.com/abcd")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "a://aaaa.com/aaaa?aaa=")!)))
        XCTAssertNotNil(stub.match(urlRequest: URLRequest(url: URL(string: "b://bbb.com/bbb?bb=")!)))
    }


    func testStub_success_with_data() async throws {
        let mockData = "hello".data(using: .utf8)!
        stub.regexRules.append(
            (/https:\/\/example.com\/hello/, .success(data: mockData))
        )
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://example.com/hello")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
    }

    func testStub_success_with_0_byte_data() async throws {
        stub.regexRules.append(
            (/https:\/\/example.com\/hello/, .success(data: Data()))
        )
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://example.com/hello")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(data, Data())
    }

    func testStub_success_custom_configuration() async throws {
        let mockData = "hello".data(using: .utf8)!
        stub.regexRules.append(
            (/https:\/\/example.com\/hello/, .success(data: mockData))
        )
        let config = URLSessionConfiguration.default
        stub.stub(urlSessionConfiguration: config)
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(from: URL(string: "https://example.com/hello")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
    }

    func testStub_failure() async throws {
        stub.regexRules.append(
            (/https:\/\/example.com\/hello/, .failure(error: URLError(.notConnectedToInternet)))
        )

        await XCTAssertThrowsAsyncError(
            try await URLSession.shared.data(from: URL(string: "https://example.com/hello")!)
        ) { error in
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testStub_cancellation() async throws {
        stub.regexRules.append(
            (/https:\/\/example.com\/hello/, .init(statusCode: 200, headerFields: nil, result: .success(Data()), delay: .seconds(5)))
        )
        let task = Task {
            await XCTAssertThrowsAsyncError(
                try await URLSession.shared.data(from: URL(string: "https://example.com/hello")!)
            ) { error in
                XCTAssertEqual((error as? URLError)?.code, .cancelled)
            }
        }
        task.cancel()
        _ = await task.result
    }


}

private extension XCTestCase {
    func XCTAssertThrowsAsyncError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            // expected error to be thrown, but it was not
            let customMessage = message()
            if customMessage.isEmpty {
                XCTFail("XCTAssertThrowsAsyncError failed: did not throw an error", file: file, line: line)
            } else {
                XCTFail(customMessage, file: file, line: line)
            }
        } catch {
            errorHandler(error)
        }
    }
}
