// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import Foundation

public enum Method: String {
    case GET
    case HEAD
    case POST
    case PUT
    case DELETE
    case CONNECT
    case OPTIONS
    case TRACE
    case PATCH
}

public struct Header {
    let name: String
    let value: String
}

public enum ResponseError: Error {
    case parse
    case badResponse
}

public class Request {
    private var url: URL
    private var method: Method = .GET
    private var headers: [Header] = []
    private var body: Data?
    
    init(url: URL) {
        self.url = url
    }
    
    init(url: String) {
        self.url = URL(string: url)!
    }
    
    public func path(_ path: String) -> Self {
        url = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .reduce(into: url) { partialResult, path in
                partialResult.append(component: path)
            }
        return self
    }
    
    public func method(_ method: Method) -> Self {
        self.method = method
        return self
    }
    
    public func header(_ name: String, _ value: String) -> Self {
        headers.append(Header(name: name, value: value))
        return self
    }
    
    public func body(_ body: Data) -> Self {
        self.body = body
        return self
    }
    
    public func fetch() -> AnyPublisher<Data, Error> {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body
        headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.name) }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response throws -> Data in
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode >= 200 && httpResponse.statusCode < 300
                else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .eraseToAnyPublisher()
    }
}

extension AnyPublisher {
    public func use(onError: ((Failure) -> Void)? = nil, onSuccess: @escaping (Output) -> Void) -> AnyCancellable {
        return receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    if let onError = onError {
                        onError(error)
                    }
                }
            } receiveValue: { value in
                onSuccess(value)
            }
    }
}

extension AnyPublisher where Output == Data {
    public func json<Item: Decodable>(_ type: Item.Type) -> AnyPublisher<Item, ResponseError> {
        return tryMap { data in
            let jsonDecoder = JSONDecoder()
            let item = try jsonDecoder.decode(Item.self, from: data)
            return item
        }
        .mapError { _ in ResponseError.parse }
        .eraseToAnyPublisher()
    }
    
    public func text() -> AnyPublisher<String, ResponseError> {
        return tryMap {
            guard let text = String(data: $0, encoding: .utf8) else {
                throw ResponseError.parse
            }
            return text
        }
        .mapError { _ in ResponseError.parse }
        .eraseToAnyPublisher()
    }
    

}

public class Fetch {
    public static func request(url: String) -> Request {
        return Request(url: url)
    }
    
    private init() {}
}
