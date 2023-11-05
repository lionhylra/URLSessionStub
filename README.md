# URLSessionStub
A simple stub to mock responses for URLSession. 

`URLSessionStub` can be used to facilitate testing code that downloads data from server. It enables you to mock the http response easily and verify the request sent to server.

# Usage

There are two ways to use this class:
 
1. If you want to stub `URLSession.shared` instance, call `start()`. And when you no longer need it, call `stop()`.

```
let stub = URLSessionStub.shared
stub.start()
stub.addRule(exactURL: "https://example.com/hello", response: .success(data: Data()))
let (data, response) = try await URLSession.shared.data(from: URL(string: "https://example.com/hello")!)
```

2. If you want to stub any `URLSession` instance created from `URLSessionConfiguration`, call `stub(urlSessionConfiguration:)`.
```
let stub = URLSessionStub.shared
let config = URLSessionConfiguration.default
stub.stub(urlSessionConfiguration: config)
let session = URLSession(configuration: config)
stub.addRule(exactURL: "https://example.com/hello", response: .success(data: Data()))
let (data, response) = try await session.data(from: URL(string: "https://example.com/hello")!)
```
