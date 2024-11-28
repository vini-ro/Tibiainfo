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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Search Section
                        searchSection
                        
                        if let character = viewModel.characterInfo {
                            if horizontalSizeClass == .regular {
                                // Landscape layout for iPad and larger screens
                                HStack(alignment: .top, spacing: 20) {
                                    VStack {
                                        characterInfoSection(character)
                                        if let accountInfo = viewModel.accountInfo {
                                            accountInfoSection(accountInfo)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack {
                                        if !viewModel.deaths.isEmpty {
                                            deathsSection
                                        }
                                        if !viewModel.otherCharacters.isEmpty {
                                            otherCharactersSection
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                // Portrait layout for iPhone and smaller screens
                                characterInfoSection(character)
                                
                                if !viewModel.deaths.isEmpty {
                                    deathsSection
                                }
                                
                                if let accountInfo = viewModel.accountInfo {
                                    accountInfoSection(accountInfo)
                                }
                                
                                if !viewModel.otherCharacters.isEmpty {
                                    otherCharactersSection
                                }
                            }
                        } else if let errorMessage = viewModel.errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        // Recent Searches Section
                        if !viewModel.recentSearches.isEmpty {
                            recentSearchesSection
                        }
                    }
                    .padding()
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    ZStack {
                        Color(.systemBackground)
                            .opacity(0.8)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.accentColor)
                            
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 120, height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                        )
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .zIndex(2)
                }
            }
            .navigationTitle("Tibia Character Info")
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Character Name", text: $characterName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onChange(of: characterName) { _, newValue in
                        // Only validate input, don't search
                        if newValue.count > 29 {
                            characterName = String(newValue.prefix(29))
                        }
                        // Remove invalid characters in real-time
                        characterName = newValue.filter { 
                            $0.isLetter || $0 == "-" || $0 == " "
                        }
                    }
                    .onSubmit {
                        performSearch()
                    }
                    .overlay(
                        Group {
                            if !characterName.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        resetView()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray.opacity(0.6))
                                            .font(.system(size: 16))
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                        }
                    )
                    .frame(height: 44)
            }
            
            Button(action: {
                performSearch()
            }) {
                Text("Search")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.headline)
            }
        }
        .padding(.horizontal)
    }
    
    private func performSearch() {
        hideKeyboard()
        viewModel.fetchCharacterInfo(name: characterName)
    }
    
    private func resetView() {
        characterName = ""
        viewModel.clearCurrentSearch()
        hideKeyboard()
    }
    
    private func characterInfoSection(_ character: CharacterInfo.CharacterData.Character) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(character.name)
                .font(.title)
                .bold()
                .minimumScaleFactor(0.75)
            
            Text(character.title ?? "Hidden")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                InfoRow(label: "Level", value: "\(character.level)")
                InfoRow(label: "Sex", value: character.sex)
                InfoRow(label: "Vocation", value: character.vocation)
                InfoRow(label: "World", value: character.world)
                InfoRow(label: "Achievement Points", value: "\(character.achievement_points)")
                InfoRow(label: "Residence", value: character.residence)
                InfoRow(label: "Last Login", value: character.last_login ?? "Hidden")
                InfoRow(label: "Account Status", value: character.account_status)
                InfoRow(label: "Married to", value: character.married_to ?? "Hidden")
                InfoRow(label: "Unlocked Titles", value: "\(character.unlocked_titles)")
                
                if let guild = character.guild {
                    InfoRow(label: "Guild", value: guild.name)
                    InfoRow(label: "Guild Rank", value: guild.rank)
                } else {
                    InfoRow(label: "Guild", value: "Hidden")
                    InfoRow(label: "Guild Rank", value: "Hidden")
                }
                
                if let houses = character.houses, !houses.isEmpty {
                    Text("Houses")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ForEach(houses, id: \.houseid) { house in
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(label: "Name", value: house.name)
                            InfoRow(label: "Town", value: house.town)
                            InfoRow(label: "Paid Until", value: house.paid)
                        }
                        .padding(.leading)
                    }
                } else {
                    InfoRow(label: "Houses", value: "Hidden")
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
            
            ForEach(viewModel.deaths, id: \.time) { death in
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
            
            InfoRow(label: "Created", value: accountInfo.created ?? "Hidden")
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
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Searches")
                .font(.headline)
            
            ForEach(viewModel.recentSearches) { search in
                Button(action: {
                    characterName = search.name
                    viewModel.fetchCharacterInfo(name: search.name, fromRecentSearch: true)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(search.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("\(search.vocation) - Level \(search.level)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("World: \(search.world)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Last updated: \(search.formattedDate)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        HStack(spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
                .font(.body)
            Spacer()
            Text(value)
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .frame(height: 32)
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
