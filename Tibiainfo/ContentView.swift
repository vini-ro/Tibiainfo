//
//  ContentView.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI

// ContentView
struct ContentView: View {
    @StateObject private var viewModel = CharacterViewModel()
    @State private var characterName: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Search Section
                    searchSection
                    
                    if viewModel.isLoading {
                        ProgressView("Loading...")
                    } else if let character = viewModel.characterInfo {
                        // Character Info Section
                        characterInfoSection(character)
                        
                        // Deaths Section
                        if !viewModel.deaths.isEmpty {
                            deathsSection
                        }
                        
                        // Account Info Section
                        if let accountInfo = viewModel.accountInfo {
                            accountInfoSection(accountInfo)
                        }
                        
                        // Other Characters Section
                        if !viewModel.otherCharacters.isEmpty {
                            otherCharactersSection
                        }
                    } else if let errorMessage = viewModel.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Tibia Character Info")
        }
    }
    
    private var searchSection: some View {
        VStack {
            TextField("Character Name", text: $characterName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
            
            Button(action: {
                performSearch()
            }) {
                Text("Search")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private func performSearch() {
        hideKeyboard()
        viewModel.fetchCharacterInfo(name: characterName)
    }
    
    private func characterInfoSection(_ character: CharacterInfo.CharacterData.Character) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(character.name)
                .font(.title)
                .bold()
            
            if let title = character.title, title != "None" {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Group {
                InfoRow(label: "Level", value: "\(character.level)")
                InfoRow(label: "Vocation", value: character.vocation)
                InfoRow(label: "World", value: character.world)
                InfoRow(label: "Achievement Points", value: "\(character.achievement_points)")
                InfoRow(label: "Residence", value: character.residence)
                
                if let marriedTo = character.married_to {
                    InfoRow(label: "Married to", value: marriedTo)
                }
                
                if let guild = character.guild {
                    InfoRow(label: "Guild", value: "\(guild.name) (\(guild.rank))")
                }
            }
            
            if let houses = character.houses, !houses.isEmpty {
                Text("Houses")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(houses, id: \.houseid) { house in
                    VStack(alignment: .leading) {
                        Text(house.name)
                            .font(.subheadline)
                        Text("\(house.town) - Paid until \(house.paid)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var deathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Deaths")
                .font(.headline)
            
            ForEach(viewModel.deaths.prefix(5), id: \.time) { death in
                VStack(alignment: .leading) {
                    Text("Level \(death.level)")
                        .font(.subheadline)
                    Text(death.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func accountInfoSection(_ accountInfo: CharacterInfo.CharacterData.AccountInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account Information")
                .font(.headline)
            
            InfoRow(label: "Created", value: accountInfo.created)
            InfoRow(label: "Loyalty Title", value: accountInfo.loyalty_title)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var otherCharactersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other Characters")
                .font(.headline)
            
            ForEach(viewModel.otherCharacters, id: \.name) { character in
                VStack(alignment: .leading) {
                    Text(character.name)
                        .font(.subheadline)
                    Text("\(character.world) - \(character.status)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#Preview {
    ContentView()
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
