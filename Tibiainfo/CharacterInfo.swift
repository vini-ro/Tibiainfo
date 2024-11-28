//
//  CharacterInfo.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import Foundation

struct CharacterInfo: Codable {
    let character: CharacterData
    let information: Information
    
    struct CharacterData: Codable {
        let character: Character
        let deaths: [Death]?
        let deaths_truncated: Bool
        let account_information: AccountInfo?
        let other_characters: [OtherCharacter]?
        
        struct Character: Codable {
            let name: String
            let title: String?
            let sex: String
            let vocation: String
            let level: Int
            let achievement_points: Int
            let world: String
            let residence: String
            let last_login: String?
            let account_status: String
            let married_to: String?
            let houses: [House]?
            let guild: Guild?
            let unlocked_titles: Int
            
            struct House: Codable {
                let name: String
                let town: String
                let paid: String
                let houseid: Int
            }
        }
        
        struct Death: Codable {
            let time: String
            let level: Int
            let reason: String
            let killers: [Killer]?
            let assists: [Killer]?
            
            struct Killer: Codable {
                let name: String
                let player: Bool
                let traded: Bool
                let summon: String?
            }
        }
        
        struct AccountInfo: Codable {
            let created: String?
            let loyalty_title: String
        }
        
        struct OtherCharacter: Codable {
            let name: String
            let world: String
            let status: String
            let deleted: Bool
            let main: Bool
            let traded: Bool
        }
        
        struct Guild: Codable {
            let name: String
            let rank: String
        }
    }
    
    struct Information: Codable {
        let api: API
        let timestamp: String
        let tibia_urls: [String]
        let status: Status
        
        struct API: Codable {
            let version: Int
            let release: String
            let commit: String
        }
        
        struct Status: Codable {
            let http_code: Int
        }
    }
}

