//
//  CharacterInfo.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import Foundation

struct CharacterInfo: Codable {
    struct Data: Codable {
        struct Character: Codable {
            let name: String
            let level: Int
            let vocation: String
            let world: String
            let sex: String
            let residence: String
            let guild: Guild?
            let lastLogin: String
            
            struct Guild: Codable {
                let name: String
                let rank: String
            }
        }
        let character: Character
    }
    let characters: Data
}
