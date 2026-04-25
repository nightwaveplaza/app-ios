//
//  APIClient.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)
    case unknown(Error)
}

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "https://api.plaza.one/v2"
    
    func request<T: Decodable>(path: String, method: String = "GET") async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(path)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                throw APIError.serverError(statusCode: statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            return try decoder.decode(T.self, from: data)
            
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.unknown(error)
        }
    }
}
