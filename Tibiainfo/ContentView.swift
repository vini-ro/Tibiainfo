//
//  ContentView.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI
import Combine

// Modelo para o JSON retornado pela API
struct CharacterInfo: Codable {
    struct CharacterData: Codable {
        struct Character: Codable {
            let name: String
            let sex: String
            let title: String
            let unlocked_titles: Int
            let vocation: String
            let level: Int
            let achievement_points: Int
            let world: String
            let residence: String
            let houses: [House]
            let guild: Guild?
            let last_login: String
            let account_status: String
            
            struct House: Codable {
                let name: String
                let town: String
                let paid: String
                let houseid: Int
            }
            
            struct Guild: Codable {
                let name: String
                let rank: String
            }
        }
        
        struct AccountInformation: Codable {
            let created: String
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
        
        let character: Character
        let deaths_truncated: Bool
        let account_information: AccountInformation
        let other_characters: [OtherCharacter]
    }
    
    struct Information: Codable {
        struct Api: Codable {
            let version: Int
            let release: String
            let commit: String
        }
        
        struct Status: Codable {
            let http_code: Int
        }
        
        let api: Api
        let timestamp: String
        let status: Status
    }
    
    let character: CharacterData
    let information: Information
}

// ViewModel para gerenciar a requisição de dados
class CharacterViewModel: ObservableObject {
    @Published var characterInfo: CharacterInfo.CharacterData.Character?
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
                self?.characterInfo = characterInfo.character.character
            })
            .store(in: &cancellables)
    }
    
    // Método para formatar data
    func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
            return dateFormatter.string(from: date)
        }
        return dateString
    }
}

// View para solicitar o nome do personagem e exibir as informações
struct ContentView: View {
    @State private var characterName: String = ""
    @ObservedObject var viewModel = CharacterViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Digite o nome do personagem", text: $characterName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Buscar Informações") {
                viewModel.fetchCharacterInfo(name: characterName)
            }
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Carregando...")
                    .padding()
            } else if let character = viewModel.characterInfo {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nome: \(character.name)")
                    Text("Sexo: \(character.sex)")
                    Text("Título: \(character.title)")
                    Text("Vocação: \(character.vocation)")
                    Text("Nível: \(character.level)")
                    Text("Pontos de Conquista: \(character.achievement_points)")
                    Text("Mundo: \(character.world)")
                    Text("Residência: \(character.residence)")
                    if let guild = character.guild {
                        Text("Guilda: \(guild.name) (\(guild.rank))")
                    }
                    Text("Último Login: \(viewModel.formatDate(character.last_login))")
                    Text("Status da Conta: \(character.account_status)")
                    // Se desejar, pode adicionar mais detalhes como houses, account_information, etc.
                }
                .padding()
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

// Estrutura principal do aplicativo
@main
struct TibiainfoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


#Preview {
    ContentView()
}
