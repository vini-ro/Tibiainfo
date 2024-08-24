//
//  ContentView.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI

struct ContentView: View {
    @State private var characterName: String = ""
    @ObservedObject var viewModel = CharacterViewModel()
    
    var body: some View {
        ZStack {
            Image("tibia_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
            
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
                        Text("Nível: \(character.level)")
                        Text("Vocação: \(character.vocation)")
                        Text("Mundo: \(character.world)")
                        Text("Sexo: \(character.sex)")
                        Text("Residência: \(character.residence)")
                        if let guild = character.guild {
                            Text("Guilda: \(guild.name) (\(guild.rank))")
                        }
                        Text("Último Login: \(character.lastLogin.formatted(date: .numeric, time: .shortened))")
                    }
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}



#Preview {
    ContentView()
}
