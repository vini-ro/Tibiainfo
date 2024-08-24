//
//  CharacterViewModel.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI
import Combine

class CharacterViewModel: ObservableObject {
    @Published var characterInfo: CharacterInfo.Data.Character?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchCharacterInfo(name: String) {
        guard !name.isEmpty else {
            self.errorMessage = "Por favor, insira um nome de personagem."
            return
        }
        
        let urlString = "https://api.tibiadata.com/v4/character/\(name)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            self.errorMessage = "URL inválida."
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        self.characterInfo = nil
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: CharacterInfo.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                switch completion {
                case .failure(let error):
                    self.errorMessage = "Erro: \(error.localizedDescription)"
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] characterInfo in
                self?.characterInfo = characterInfo.characters.character
            })
            .store(in: &cancellables)
    }
}


#Preview {
    CharacterViewModel()
}
