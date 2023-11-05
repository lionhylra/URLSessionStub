import Foundation

public final class URLSessionStub {

    var regexRules: [(Regex<Substring>, MockResponse)] = []

    var customRule: ((URLRequest) -> MockResponse?)?

    var onReceiveRequest: ((URLRequest) -> Void)?

    public static let shared = URLSessionStub()

    init() {
        URLProtocol.stub = self
    }

    public func start() {
        Foundation.URLProtocol.registerClass(URLSessionStub.URLProtocol.self)
    }

    public func stop() {
        Foundation.URLProtocol.unregisterClass(URLSessionStub.URLProtocol.self)
    }

    public func stub(urlSessionConfiguration: URLSessionConfiguration) {
        urlSessionConfiguration.protocolClasses = [URLSessionStub.URLProtocol.self]
    }

    public func addRule(regex: Regex<Substring>, response: MockResponse) {
        regexRules.append((regex, response))
    }

    public func addRule(exactURL: String, response: MockResponse) {
        regexRules.append((Regex(verbatim: exactURL), response))
    }

    public func addCustomRule(_ rule: @escaping (URLRequest) -> MockResponse?) {
        customRule = rule
    }

    public func setOnReceiveRequestObserver(_ closure: ((URLRequest) -> Void)?) {
        onReceiveRequest = closure
    }

    public func removeAllRules() {
        regexRules.removeAll()
        customRule = nil
    }

    func match(urlRequest: URLRequest) -> MockResponse? {
        if let customRule, let mockResponse = customRule(urlRequest) {
                return mockResponse
        }
        guard let urlString = urlRequest.url?.absoluteString else {
            assertionFailure()
            return nil
        }
        for (regex, mockResponse) in regexRules {
            if let _ = try? regex.wholeMatch(in: urlString) {
                return mockResponse
            }
        }
        return nil
    }
}

extension URLSessionStub {
    class URLProtocol: Foundation.URLProtocol {

        static var stub: URLSessionStub!
        private var workItem: DispatchWorkItem?
        private let queue = DispatchQueue(label: (String(describing: URLSessionStub.self) + "-" + UUID().uuidString))

        override class func canInit(with request: URLRequest) -> Bool {
            stub.match(urlRequest: request) != nil
        }

        override public func startLoading() {
            guard let mockResponse = Self.stub.match(urlRequest: request),
                  let response = HTTPURLResponse(url: request.url!, statusCode: mockResponse.statusCode, httpVersion: mockResponse.httpVersion, headerFields: mockResponse.headerFields)
            else {
                return
            }
            Self.stub.onReceiveRequest?(request)
            let workItem = DispatchWorkItem {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                switch mockResponse.result {
                case .success(let data):
                    self.client?.urlProtocol(self, didLoad: data)
                    self.client?.urlProtocolDidFinishLoading(self)
                case .failure(let error):
                    self.client?.urlProtocol(self, didFailWithError: error)
                }
                self.workItem = nil
            }
            self.workItem = workItem
            if let delay = mockResponse.delay {
                queue.asyncAfter(deadline: .now() + delay, execute: workItem)
            } else {
                queue.async(execute: workItem)
            }
        }

        override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override public func stopLoading() {
            queue.async {
                guard let workItem = self.workItem else { return }
                workItem.cancel()
                self.client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            }
        }
    }
}

extension URLSessionStub {

    public struct MockResponse {
        public let statusCode: Int
        public let httpVersion: String = "HTTP/1.1"
        public let headerFields: [String: String]?
        public let result: Result<Data, any Error>
        public let delay: DispatchTimeInterval?

        public init(
            statusCode: Int,
            headerFields: [String : String]? = nil,
            result: Result<Data, any Error>,
            delay: DispatchTimeInterval? = nil
        ) {
            self.statusCode = statusCode
            self.headerFields = headerFields
            self.result = result
            self.delay = delay
        }

        static func success(data: Data) -> Self {
            self.init(statusCode: 200, headerFields: ["Content-Type": "application/json"], result: .success(data), delay: nil)
        }

        static func failure(error: URLError) -> Self {
            self.init(statusCode: 999, headerFields: nil, result: .failure(error), delay: nil)
        }
    }
}
