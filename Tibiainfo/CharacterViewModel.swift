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
        
        let formattedName = cleanedName.replacingOccurrences(of: " ", with: "+")
        
        // Don't perform search for very short names
        guard formattedName.count >= 2 else {
            return
        }
        
        guard !formattedName.isEmpty else {
            self.errorMessage = "Please enter a character name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let cacheKey = formattedName as NSString
        
        // Try to get cached data first
        if let cachedInfo = getCachedData(for: cacheKey) {
            DispatchQueue.main.async { [weak self] in
                self?.updateCharacterData(cachedInfo)
                // Don't update recent searches if we're clicking from recent searches
                if !fromRecentSearch {
                    self?.saveRecentSearch(name: name, character: cachedInfo.character.character)
                }
                self?.isLoading = false
            }
            
            // If not refreshing and we have cached data, return early
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
        
        // Continue with network request
        guard let url = URL(string: "https://api.tibiadata.com/v4/character/\(formattedName)") else {
            self.errorMessage = "Invalid character name"
            self.isLoading = false
            return
        }
        
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
                    throw URLError(.badServerResponse)
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 404:
                    throw NetworkError.characterNotFound
                default:
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                }
            }
            .decode(type: CharacterInfo.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                // Ensure minimum loading time
                let elapsed = Date().timeIntervalSince(loadingStartTime)
                let remainingTime = max(0, minimumLoadingTime - elapsed)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                    self.isLoading = false
                    if case .failure(let error) = completion {
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
        // Batch UI updates
        DispatchQueue.main.async { [weak self] in
            self?.characterInfo = info.character.character
            self?.deaths = info.character.deaths ?? []
            self?.accountInfo = info.character.account_information
            self?.otherCharacters = (info.character.other_characters ?? []).filter { 
                $0.name.lowercased() != info.character.character.name.lowercased() 
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let message: String
        switch error {
        case NetworkError.characterNotFound:
            os_log(.error, "🔍 Character not found")
            message = "Character not found"
        case NetworkError.serverError(let code):
            message = "Server error (Status: \(code))"
        case let decodingError as DecodingError:
            switch decodingError {
            case .keyNotFound(_, _):
                // Instead of showing the missing data error, we'll handle it in the view
                return
            case .typeMismatch(let type, _):
                message = "Invalid data format"
                os_log(.error, "Expected Type: %{public}@", String(describing: type))
            case .valueNotFound(_, _):
                // Instead of showing the missing value error, we'll handle it in the view
                return
            case .dataCorrupted(let context):
                message = "Data corrupted: \(context.debugDescription)"
                os_log(.error, "Context: %{public}@", context.debugDescription)
            @unknown default:
                message = "Unknown decoding error"
            }
        default:
            message = "Failed to load character: \(error.localizedDescription)"
        }
        os_log(.error, "❌ Final error message: %{public}@", message)
        errorMessage = message
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
    
    var errorDescription: String? {
        switch self {
        case .characterNotFound:
            return "Character not found"
        case .serverError(let code):
            return "Server error (Status: \(code))"
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
