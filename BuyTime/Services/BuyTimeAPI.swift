//
//  BuyTimeAPI.swift
//  BuyTime
//
//  API client for BuyTime backend with automatic JWT refresh handling.
//

import Foundation
import Clerk

enum APIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case badRequest(String)
    case serverError
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Not authorized. Please sign in again."
        case .notFound:
            return "Resource not found."
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .serverError:
            return "Server error. Please try again later."
        case .decodingError:
            return "Failed to parse server response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

class BuyTimeAPI {
    static let shared = BuyTimeAPI()
    
    private let baseURL = Secrets.apiBaseURL
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Gets a fresh JWT token from Clerk.
    /// Clerk automatically handles caching and refresh - if the token is about to expire,
    /// it fetches a new one. Always call this before each API request.
    private func getAuthToken() async throws -> String {
        guard let session = Clerk.shared.session else {
            throw APIError.unauthorized
        }
        
        // getToken() automatically handles refresh:
        // - Returns cached token if still valid
        // - Fetches new token if cached one expires within 10 seconds (default buffer)
        guard let tokenResponse = try await session.getToken() else {
            throw APIError.unauthorized
        }
        
        return tokenResponse.jwt
    }
    
    /// Force refresh the token (use when you know server-side data changed)
    private func getAuthTokenForceRefresh() async throws -> String {
        guard let session = Clerk.shared.session else {
            throw APIError.unauthorized
        }
        
        // skipCache: true forces a network request for a fresh token
        guard let tokenResponse = try await session.getToken(.init(skipCache: true)) else {
            throw APIError.unauthorized
        }
        
        return tokenResponse.jwt
    }
    
    // MARK: - Request Helpers
    
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        forceTokenRefresh: Bool = false
    ) async throws -> T {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get fresh token for each request - Clerk handles caching internally
        let token = forceTokenRefresh
            ? try await getAuthTokenForceRefresh()
            : try await getAuthToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
            if apiResponse.success, let responseData = apiResponse.data {
                return responseData
            } else {
                throw APIError.badRequest(apiResponse.error ?? "Unknown error")
            }
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 400...499:
            if let apiResponse = try? JSONDecoder().decode(APIResponse<T>.self, from: data) {
                throw APIError.badRequest(apiResponse.error ?? "Bad request")
            }
            throw APIError.badRequest("Bad request")
        default:
            throw APIError.serverError
        }
    }
    
    // MARK: - User Endpoints
    
    struct UserProfile: Decodable {
        let id: String
        let email: String?
        let displayName: String?
        let subscriptionTier: String
        let subscriptionStatus: String
        let subscriptionExpiresAt: String?
        let createdAt: String
        let balance: UserBalance?
    }
    
    struct UserBalance: Decodable {
        let availableMinutes: Int
        let currentStreakDays: Int
    }
    
    /// GET /api/users/me
    func getUser() async throws -> UserProfile {
        try await makeRequest(endpoint: "/api/users/me")
    }
    
    /// PATCH /api/users/me
    func updateUser(displayName: String) async throws -> UserProfile {
        let body = try JSONEncoder().encode(["displayName": displayName])
        return try await makeRequest(endpoint: "/api/users/me", method: "PATCH", body: body)
    }
    
    struct DeleteResponse: Decodable {
        let deleted: Bool
    }
    
    /// DELETE /api/users/me
    func deleteUser() async throws -> DeleteResponse {
        try await makeRequest(endpoint: "/api/users/me", method: "DELETE")
    }
    
    struct UserPreferences: Decodable {
        let focusDurationMinutes: Int
        let focusMode: String
        let updatedAt: String
    }
    
    private struct PreferencesBody: Encodable {
        let focusDurationMinutes: Int
        let focusMode: String
    }
    
    func getPreferences() async throws -> UserPreferences {
        try await makeRequest(endpoint: "/api/preferences")
    }
    
    func updatePreferences(focusDurationMinutes: Int, focusMode: String) async throws -> UserPreferences {
        let body = try JSONEncoder().encode(
            PreferencesBody(focusDurationMinutes: focusDurationMinutes, focusMode: focusMode)
        )
        
        return try await makeRequest(endpoint: "/api/preferences", method: "PATCH", body: body)
    }
    
    // MARK: - Balance Endpoints

    struct Balance: Decodable {
        let availableMinutes: Int
        let currentStreakDays: Int
        let lastSessionDate: String?
        let updatedAt: String
        let today: TodayStats?

        struct TodayStats: Decodable {
            let earnedMinutes: Int
            let spentMinutes: Int
            let sessionsCompleted: Int
            let sessionsFailed: Int
        }
    }

    private struct UpdateBalanceBody: Encodable {
        let availableMinutes: Int
    }

    /// GET /api/balance
    func getBalance() async throws -> Balance {
        try await makeRequest(endpoint: "/api/balance")
    }

    /// PATCH /api/balance
    func updateBalance(availableMinutes: Int) async throws -> Balance {
        let body = try JSONEncoder().encode(UpdateBalanceBody(availableMinutes: availableMinutes))
        return try await makeRequest(endpoint: "/api/balance", method: "PATCH", body: body)
    }

    // MARK: - Retry Helper for Webhook Timing
    
    /// After sign-up, the webhook needs time to create the user in the database.
    /// This polls until the user is available.
    func waitForUserCreation(maxRetries: Int = 5, delaySeconds: UInt64 = 1) async throws -> UserProfile {
        for attempt in 0..<maxRetries {
            do {
                return try await getUser()
            } catch APIError.notFound {
                // User not yet created by webhook, wait and retry
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                }
                continue
            }
        }
        throw APIError.notFound
    }
}
