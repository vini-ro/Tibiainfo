//
//  CharacterViewModel.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI
import Combine
import os.log
import Network

class CharacterViewModel: ObservableObject {
    @Published private(set) var characterInfo: CharacterInfo.CharacterData.Character?
    @Published private(set) var deaths: [CharacterInfo.CharacterData.Death] = []
    @Published private(set) var accountInfo: CharacterInfo.CharacterData.AccountInfo?
    @Published private(set) var otherCharacters: [CharacterInfo.CharacterData.OtherCharacter] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var recentSearches: [RecentSearch] = []
    @Published private(set) var achievements: [CharacterInfo.CharacterData.Achievement] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let cache: NSCache<NSString, CachedCharacterInfo> = {
        let cache = NSCache<NSString, CachedCharacterInfo>()
        cache.countLimit = 50  // Store up to 50 characters
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB limit
        return cache
    }()
    private let cacheTimeout: TimeInterval = 60 // 1 minute cache
    private let userDefaults = UserDefaults.standard
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 4
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    private let nameValidator = TibiaNameValidator()
    
    init() {
        loadRecentSearches()
    }
    
    private func loadRecentSearches() {
        if let data = userDefaults.data(forKey: recentSearchesKey),
           let searches = try? JSONDecoder().decode([RecentSearch].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearch(name: String, character: CharacterInfo.CharacterData.Character) {
        var searches = recentSearches
        
        // Remove existing entry if present
        searches.removeAll { $0.name.lowercased() == name.lowercased() }
        
        // Add new search to beginning
        let newSearch = RecentSearch(
            name: character.name,
            level: character.level,
            vocation: character.vocation,
            world: character.world,
            lastUpdated: Date()
        )
        searches.insert(newSearch, at: 0)
        
        // Keep only the most recent searches
        if searches.count > maxRecentSearches {
            // Remove the oldest search and its associated cache
            if let oldestSearch = searches.last {
                let cacheKey = oldestSearch.name.replacingOccurrences(of: " ", with: "+") as NSString
                cache.removeObject(forKey: cacheKey)
            }
            searches = Array(searches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(searches) {
            userDefaults.set(encoded, forKey: recentSearchesKey)
        }
        
        recentSearches = searches
    }
    
    func fetchCharacterInfo(name: String, isRefreshing: Bool = false, fromRecentSearch: Bool = false) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear previous state before new search
        if !isRefreshing {
            clearCurrentSearch()
        }
        
        // Validate name according to Tibia rules
        if let validationError = nameValidator.validate(name: cleanedName) {
            self.errorMessage = validationError
            self.isLoading = false
            return
        }
        
        // Properly encode the name for URL
        guard let formattedName = cleanedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            self.errorMessage = "Invalid character name"
            self.isLoading = false
            return
        }
        
        // Don't perform search for very short names
        guard cleanedName.count >= 2 else {
            return
        }
        
        guard !cleanedName.isEmpty else {
            self.errorMessage = "Please enter a character name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let cacheKey = cleanedName as NSString // Use original cleaned name as cache key
        
        // Remove old cache if refreshing
        if isRefreshing {
            cache.removeObject(forKey: cacheKey)
        }
        
        // Try to get cached data first
        if let cachedInfo = getCachedData(for: cacheKey) {
            DispatchQueue.main.async { [weak self] in
                self?.updateCharacterData(cachedInfo)
                if !fromRecentSearch {
                    self?.saveRecentSearch(name: cleanedName, character: cachedInfo.character.character)
                }
                self?.isLoading = false
            }
            
            if !isRefreshing {
                return
            }
        }
        
        // If we're offline and have no cache, show error
        guard NetworkMonitor.shared.isConnected else {
            self.errorMessage = "No internet connection and no cached data available"
            self.isLoading = false
            return
        }
        
        // Use the properly encoded URL
        guard let url = URL(string: "https://api.tibiadata.com/v4/character/\(formattedName)") else {
            self.errorMessage = "Invalid character name"
            self.isLoading = false
            return
        }
        
        // Add logging to debug URL
        print("Fetching character from URL: \(url.absoluteString)")
        
        // Cancel any existing requests
        cancellables.removeAll()
        
        // Add a minimum loading time for better UX
        let minimumLoadingTime: TimeInterval = 0.5
        let loadingStartTime = Date()
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        urlSession
            .dataTaskPublisher(for: url)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.connectionError("Invalid server response")
                }
                
                // Print response for debugging
                print("Response status code: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
                
                // Print received data for debugging
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Received data: \(dataString)")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 404:
                    throw NetworkError.characterNotFound
                case 500...599:
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                default:
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                }
            }
            .decode(type: CharacterInfo.self, decoder: decoder)
            .catch { error -> AnyPublisher<CharacterInfo, Error> in
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, _):
                        if key.stringValue == "loyalty_title" || 
                           key.stringValue == "created" {
                            return Empty().eraseToAnyPublisher()
                        }
                        return Fail(error: NetworkError.decodingError("Missing required data: \(key.stringValue)")).eraseToAnyPublisher()
                    case .dataCorrupted(let context):
                        return Fail(error: NetworkError.decodingError("Data corrupted: \(context.debugDescription)")).eraseToAnyPublisher()
                    case .typeMismatch(_, let context):
                        return Fail(error: NetworkError.decodingError("Invalid data format at: \(context.debugDescription)")).eraseToAnyPublisher()
                    case .valueNotFound(_, let context):
                        return Fail(error: NetworkError.decodingError("Missing value at: \(context.debugDescription)")).eraseToAnyPublisher()
                    @unknown default:
                        return Fail(error: NetworkError.decodingError("Unknown decoding error")).eraseToAnyPublisher()
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                let elapsed = Date().timeIntervalSince(loadingStartTime)
                let remainingTime = max(0, minimumLoadingTime - elapsed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        // Print the full error for debugging
                        print("Error fetching character: \(error)")
                        self.handleError(error)
                    }
                }
            } receiveValue: { [weak self] characterInfo in
                guard let self = self else { return }
                
                // Handle success with minimum loading time
                let elapsed = Date().timeIntervalSince(loadingStartTime)
                let remainingTime = max(0, minimumLoadingTime - elapsed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                    self.cacheData(characterInfo, for: cacheKey)
                    self.updateCharacterData(characterInfo)
                    if !fromRecentSearch {
                        self.saveRecentSearch(name: name, character: characterInfo.character.character)
                    }
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
    
    private func getCachedData(for key: NSString) -> CharacterInfo? {
        guard let cached = cache.object(forKey: key) else { return nil }
        
        // Check if cache is still valid
        let now = Date()
        if now.timeIntervalSince(cached.timestamp) > cacheTimeout {
            cache.removeObject(forKey: key)
            return nil
        }
        
        return cached.characterInfo
    }
    
    private func cacheData(_ info: CharacterInfo, for key: NSString) {
        let cached = CachedCharacterInfo(characterInfo: info, timestamp: Date())
        // Set cost based on approximate memory usage
        let cost = NSString(string: info.character.character.name).length * 2
        cache.setObject(cached, forKey: key, cost: cost)
    }
    
    private func updateCharacterData(_ info: CharacterInfo) {
        DispatchQueue.main.async { [weak self] in
            self?.characterInfo = info.character.character
            self?.deaths = info.character.deaths ?? []
            self?.achievements = info.character.achievements ?? []
            
            if let accountInfo = info.character.account_information {
                self?.accountInfo = accountInfo
            }
            
            self?.otherCharacters = info.character.other_characters ?? []
        }
    }
    
    private func handleError(_ error: Error) {
        var errorMessage: String
        
        switch error {
        case NetworkError.characterNotFound:
            os_log(.error, "🔍 Character not found")
            errorMessage = "Character not found"
        case NetworkError.serverError(let code):
            errorMessage = "Server error (Status: \(code))"
        case NetworkError.decodingError(let message):
            errorMessage = "Data error: \(message)"
        case NetworkError.connectionError(let message):
            errorMessage = "Connection error: \(message)"
        default:
            errorMessage = "Failed to load character: \(error.localizedDescription)"
        }
        
        os_log(.error, "❌ Final error message: %{public}@", errorMessage)
        self.errorMessage = errorMessage
    }
    
    func clearCurrentSearch() {
        characterInfo = nil
        deaths = []
        accountInfo = nil
        otherCharacters = []
        errorMessage = nil
        isLoading = false
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case characterNotFound
    case serverError(statusCode: Int)
    case decodingError(String)
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .characterNotFound:
            return "Character not found"
        case .serverError(let code):
            return "Server error (Status: \(code))"
        case .decodingError(let message):
            return "Data error: \(message)"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}

// MARK: - Recent Searches
struct RecentSearch: Codable, Identifiable {
    var id: UUID
    let name: String
    let level: Int
    let vocation: String
    let world: String
    let lastUpdated: Date
    
    init(id: UUID = UUID(), name: String, level: Int, vocation: String, world: String, lastUpdated: Date) {
        self.id = id
        self.name = name
        self.level = level
        self.vocation = vocation
        self.world = world
        self.lastUpdated = lastUpdated
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, level, vocation, world, lastUpdated
    }
}

// MARK: - Cached Data
class CachedCharacterInfo {
    let characterInfo: CharacterInfo
    let timestamp: Date
    
    init(characterInfo: CharacterInfo, timestamp: Date) {
        self.characterInfo = characterInfo
        self.timestamp = timestamp
    }
}

// Add NetworkMonitor class
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private var monitor: NWPathMonitor
    private(set) var isConnected: Bool = true
    
    private init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        self.monitor.start(queue: queue)
    }
}

// Add this class to handle name validation
class TibiaNameValidator {
    private let minLength = 2
    private let maxLength = 29
    private let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ- ")
    
    func validate(name: String) -> String? {
        // Check length
        guard name.count >= minLength else {
            return "Name must be at least \(minLength) characters long"
        }
        guard name.count <= maxLength else {
            return "Name cannot be longer than \(maxLength) characters"
        }
        
        // Check for invalid characters
        let nameSet = CharacterSet(charactersIn: name)
        guard allowedCharacters.isSuperset(of: nameSet) else {
            return "Name can only contain letters, spaces, and hyphens"
        }
        
        // Check for leading/trailing hyphens
        guard !name.hasPrefix("-") && !name.hasSuffix("-") else {
            return "Name cannot start or end with a hyphen"
        }
        
        // Check for double spaces and double hyphens
        guard !name.contains("  ") && !name.contains("--") else {
            return "Name cannot contain double spaces or double hyphens"
        }
        
        return nil // nil means validation passed
    }
}
