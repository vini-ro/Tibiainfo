//
//  CharacterViewModel.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI
import Combine
import os.log

class CharacterViewModel: ObservableObject {
    @Published private(set) var characterInfo: Character?
    @Published private(set) var deaths: [CharacterDeath] = []
    @Published private(set) var accountInfo: CharacterAccountInfo?
    @Published private(set) var otherCharacters: [Character] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let cache = NSCache<NSString, CachedCharacterInfo>()
    private let cacheTimeout: TimeInterval = 300 // 5 minutes cache
    
    func fetchCharacterInfo(name: String) {
        let formattedName = name.replacingOccurrences(of: " ", with: "+").lowercased()
        
        guard let url = URL(string: "https://api.tibiadata.com/v4/character/\(formattedName)") else {
            self.errorMessage = "Invalid character name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        
        URLSession.shared
            .dataTaskPublisher(for: url)
            .receive(on: DispatchQueue.main)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                os_log(.debug, "📡 Network Response [%{public}d] for character: %{public}@", httpResponse.statusCode, name)
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    os_log(.debug, "📥 Raw JSON Response: %{public}@", jsonString)
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
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    os_log(.error, "❌ Error fetching character: %{public}@", String(describing: error))
                    if let decodingError = error as? DecodingError {
                        os_log(.error, "🔍 Decoding Error: %{public}@", String(describing: decodingError))
                    }
                    self?.handleError(error)
                }
            } receiveValue: { [weak self] characterInfo in
                os_log(.debug, "✅ Successfully decoded character info for: %{public}@", name)
                self?.updateCharacterData(characterInfo)
            }
            .store(in: &cancellables)
    }
    
    private func updateCharacterData(_ info: CharacterInfo) {
        self.characterInfo = info.character.character
        self.deaths = info.character.deaths ?? []
        self.accountInfo = info.character.account_information
        self.otherCharacters = info.character.other_characters ?? []
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
            case .keyNotFound(let key, let context):
                message = "Missing data: \(key.stringValue)"
                os_log(.error, "Context: %{public}@", context.debugDescription)
                os_log(.error, "Coding Path: %{public}@", context.codingPath.description)
            case .typeMismatch(let type, let context):
                message = "Invalid data format at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
                os_log(.error, "Expected Type: %{public}@", type.description)
                os_log(.error, "Context: %{public}@", context.debugDescription)
            case .valueNotFound(let type, let context):
                message = "Missing value of type \(type)"
                os_log(.error, "Context: %{public}@", context.debugDescription)
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
}

// MARK: - Caching
private extension CharacterViewModel {
    final class CachedCharacterInfo: NSObject {
        let characterInfo: CharacterInfo
        let timestamp: Date
        
        init(characterInfo: CharacterInfo, timestamp: Date) {
            self.characterInfo = characterInfo
            self.timestamp = timestamp
            super.init()
        }
    }
    
    func getCachedData(for name: String) -> CharacterInfo? {
        guard let cached = cache.object(forKey: name as NSString) else { return nil }
        if Date().timeIntervalSince(cached.timestamp) > cacheTimeout {
            cache.removeObject(forKey: name as NSString)
            return nil
        }
        return cached.characterInfo
    }
    
    func cacheData(_ info: CharacterInfo, for name: String) {
        let cached = CachedCharacterInfo(characterInfo: info, timestamp: Date())
        cache.setObject(cached, forKey: name as NSString)
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
